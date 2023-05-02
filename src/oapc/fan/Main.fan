//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 May 2023  Brian Frank  Creation
//

using util
using yaml

**
** OAP compiler shell command line interface program
**
class Main : AbstractMain
{
  @Opt { help = "Output directory" }
  File? outDir

  @Arg { help = "Data dir to process" }
  File? dataDir

  override Int run()
  {
    // make sure dir exists and we have a well known file
    if (dataDir == null || !dataDir.exists) { echo("Invalid dataDir: $dataDir"); return 1 }
    if (!dataDir.plus(`hvac/`).exists) { echo("Not found: ${dataDir}hvac/"); return 1 }

    // if output dir not specified use src/xeto/oap/
    if (outDir == null) outDir = `src/xeto/oap/`.toFile
    else if (!outDir.isDir) { echo("outDir is not dir: $outDir"); return 1 }

    // pipline
    parse
    generate

    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Parsing
//////////////////////////////////////////////////////////////////////////

  Void parse()
  {
    echo
    echo("Parsing...")
    dataDir.list.each |sub|
    {
      // only process sub-dirs
      if (!sub.isDir) return

      // don't know what ui/ is but its all dups
      if (sub.name == "ui") return

      // parse defs
      parseWalk(sub)
    }
    echo("Parsed [$fileCount files]")
  }

  Void parseWalk(File f)
  {
    if (f.ext == "yaml") return parseYaml(f)
    if (f.name.startsWith("kpi")) return // skip
    if (f.isDir) f.list.each |kid| { parseWalk(kid) }
  }

  Void parseYaml(File f)
  {
    //echo("Parse [$f]")
    fileCount++
    loc := FileLoc(f.parent.name + "/" + f.name)
    files.add(loc)
    try
    {
      // each file is one doc with a map keyed by the codes
      list := YamlReader(f).parse.list
      if (list.size != 1) throw Err("Expecting only one document")
      YamlMap top := list[0]
      top.map.each |body, key|
      {
        code := (Str)key.content
        parseAdd(code, body.decode, loc)
      }
    }
    catch (Err e)
    {
      echo("FAILED")
      e.trace
    }
  }

  Void parseAdd(Str code, Str:Obj body, FileLoc loc)
  {
    name := body["name"] ?: throw Err("Missing name: $code")
    def := Def(loc, code, name, body)

    dup := defsByCode[code]
    if (dup != null)
    {
      echo("Duplicate code $code.toCode: $dup, $def")
      return
    }

    defsByCode.add(code, def)
  }

//////////////////////////////////////////////////////////////////////////
// Gen
//////////////////////////////////////////////////////////////////////////

  Void generate()
  {
    outDir.delete

    echo
    echo("Generating...")
    genLib
    files.each |loc|
    {
      // find all defs in file so we output using same file structure
      defs := defsByCode.findAll |d| { d.loc === loc }.vals
      genFile(loc, defs)
    }
    echo
  }

  Void genLib()
  {
    file := outDir + `lib.xeto`
    file.out.printLine(
       """// Auto-generated  ${DateTime.now.toLocale}

          pragma: Lib <
            doc: "Ontology Alignment Project"
            version: "1.1.0"
            depends: {
              { lib: "sys" }
              { lib: "ph" }
            }
            org: {
              dis: "Ontology Alignment Project"
              uri: "https://oap.cloud.buildingsiot.com/1.1/"
            }
          >
          """).close
  }

  Void genFile(FileLoc loc, Def[] defs)
  {
    file := outDir + toFileName(loc).toUri

    //echo("Generate [$file]")
    out := file.out
    out.printLine("// Auto-generated " + DateTime.now.toLocale)
    defs.each |def| { genDef(out, def) }
    out.printLine
    out.close
  }

  Str toFileName(FileLoc loc)
  {
    // the yaml naming convention often duplicates the folder name
    // into the file name; but for Xeto we have to flatten the dirs
    name := loc.file
    if (!name.endsWith(".yaml")) throw Err(name)
    slash := name.index("/")
    parent := name[0..<slash]
    if (parent == "environment-sensing") parent = "env"
    rest := name[slash+1..-6]
    rest = rest.replace("."+parent, "")
               .replace(".envs", "")
               .replace(".meter", "")
               .replace(".network", "")
    rest = rest.replace(".", "-")
    return parent + "-" + rest + ".xeto"
  }

  Void genDef(OutStream out, Def def)
  {
    extends := def.body["extends"]
    phType := phType(def)

    out.printLine
    genDefDescription(out, def)
    out.printLine(def.code + ": " + (extends ?: phType) + " {")

    // marker "type" tags
    def.typeMarkers.each |tag|
    {
      if (tag == phType.lower) return
      out.printLine("  $tag")
    }

    // value "type" tags
    def.typeVals.each |v, n|
    {
      genDefTypeVal(out, def, n, v)
    }

    // optional "type" tags
    typeOptional := def.haystack["type_optional"] as Str[]
    if (typeOptional != null)
    {
      typeOptional.each |tag| { out.printLine("  ${tag}: Marker?") }
    }

    // points
    points := def.body["points"] as List
    if (points != null) genDefPoints(out, def, points)

    out.printLine("}")
  }

  Str phType(Def def)
  {
    tags := def.typeMarkers
    if (tags.contains("equip")) return "Equip"
    if (tags.contains("point")) return "Point"
    if (tags.contains("space")) return "Space"
    if (tags.contains("site"))  return "Site"
    return "Dict"
  }

  Void genDefDescription(OutStream out, Def def)
  {
    d := def.description
    if (d.size < 80) return out.printLine("// $d")

    // try to put comments no loner than 80 chars wide
    curLine := 0
    words := d.split(' ')
    words.each |word|
    {
      if (curLine == 0) { out.print("\n// "); curLine = 3 }
      out.print(word)
      curLine += word.size + 1
      if (curLine < 80) out.print(" ")
      else curLine = 0
    }
    out.printLine
  }

  Void genDefTypeVal(OutStream out, Def def, Str n, Obj v)
  {
    // treat the non-marker type tags specially
    switch (n)
    {
      case "primaryFunction": out.printLine("  $n: Str $v.toStr.toCode")
      case "phase":           out.printLine("  $n: Str")
      case "stage":           out.printLine("  $n: Int $v")
      default:                echo("WARN: unsupported value type tag: $n = $v $def")
    }
  }

  Void genDefPoints(OutStream out, Def def, Str[] points)
  {
    if (points.isEmpty) return echo("WARN: empty points: $def")
    out.printLine("  points: {")
    points.each |point|
    {
      pointDef := defsByCode[point]
      if (pointDef == null) return echo("WARN: unknown point def $point in $def")
      out.printLine("    ${point}?")
    }
    out.printLine("  }")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  FileLoc[] files := [,]
  Str:Def defsByCode := [:] { ordered = true }
  Int fileCount
}

**************************************************************************
** Def
**************************************************************************

const class Def
{
  new make(FileLoc loc, Str code, Str name, Str:Obj body)
  {
    haystack := body["haystack"] as Str:Obj ?: Str:Obj[:]

    typeMarkers := Str[,]
    typeVals := Str:Obj[:]
    type := haystack["type"] as Obj[]
    if (type != null)
    {
      type.each |obj|
      {
        if (obj is Str)
        {
          typeMarkers.add(obj)
        }
        else
        {
          typeVals.addAll(obj)
        }
      }
    }

    this.loc         = loc
    this.code        = code
    this.name        = name
    this.body        = body
    this.haystack    = haystack
    this.typeMarkers = typeMarkers
    this.typeVals    = typeVals
  }

  const FileLoc loc
  const Str code
  const Str name
  const Str:Obj body
  const Str:Obj haystack
  const Str[] typeMarkers
  const Str:Obj typeVals

  Str description()
  {
    body["description"] ?: name
  }

  override Str toStr() { "$code $name [$loc]" }
}


