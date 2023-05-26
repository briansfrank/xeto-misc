//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 May 2023  Brian Frank  Creation
//

using util
using data
using haystack
using defc
using xetoTools

**
** Generate JSON file for spec source
**
class JsonSrc : XetoCmd
{
  override Str name() { "json-src" }

  override Str summary() { "Generate JSON file for lib source code" }

  @Opt { help = "Output file (default to stdout)" }
  File? out

  @Arg { help = "Lib to compile into table of contents" }
  Str? lib

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto json-src ashrae.g36")
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    if (lib == null)
    {
      echo("Must specify input lib")
      return 1
    }

    lib := env.lib(this.lib)

    src := loadSource(lib)
    dict := genDict(lib, src)

    withOut(this.out) |out|
    {
      env.print(dict, out, env.dict1("json", env.marker))
    }
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Load Source
//////////////////////////////////////////////////////////////////////////

  private Str:Str[] loadSource(DataLib lib)
  {
    acc := Str:Str[][:]
    entry := env.registry.get(lib.qname)
    if (!entry.isSrc) throw Err("Lib source not available: $lib")

    entry.srcDir.list.each |file|
    {
      if (file.ext != "xeto") return
      lines := file.readAllLines
      acc[file.name] = lines
    }

    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Generate
//////////////////////////////////////////////////////////////////////////

  private Dict genDict(DataLib lib, Str:Str[] files)
  {
    acc := Str:Dict[:]

    lib.slotsOwn.each |x|
    {
      filename := x.loc.file.toUri.name
      src := toSource(x, files[filename])
      acc[x.name] = env.dict2("loc", filename + ":" + x.loc.line, "src", src)
    }

    return env.dictMap(acc)
  }

  private Str toSource(DataSpec x, Str[]? file)
  {
    if (file == null) return ""

    // work back to get comment lines
    start := x.loc.line - 1
    end := start
    while (start > 0 && file[start-1].startsWith("//")) start--

    // find closing bracket - we assume its a "}" in column zero
    for (i := start+1; i<file.size; ++i)
    {
      line := file[i]
      if (line.startsWith("}")) { end = i; break }
    }

    return file[start..end].join("\n")
  }
}


