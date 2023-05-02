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
    files.each |loc|
    {
      // find all defs in file so we output using same file structure
      defs := defsByCode.findAll |d| { d.loc === loc }.vals
      generateFile(loc, defs)
    }
    echo
  }

  Void generateFile(FileLoc loc, Def[] defs)
  {
    if (!loc.file.endsWith(".yaml")) throw Err()
    file := outDir + (loc.file[0..-6] + ".xeto").toUri

    echo("Generate [$file]")
    out := file.out
    out.printLine("// Auto-generated " + DateTime.now.toLocale)
    defs.each |def| { generateDef(out, def) }
    out.printLine
    out.close
  }

  Void generateDef(OutStream out, Def def)
  {
    extends := def.body["extends"]
    phType := phType(def)

    out.printLine
    out.printLine("// " + def.description)
    out.printLine(def.code + ": " + (extends ?: phType) + " {")
    def.typeMarkers.each |tag|
    {
      if (tag == phType.lower) return
      out.printLine("  $tag")
    }
    def.typeVals.each |v, n|
    {
      generateDefTypeVal(out, def, n, v)
    }
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

  Void generateDefTypeVal(OutStream out, Def def, Str n, Obj v)
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


