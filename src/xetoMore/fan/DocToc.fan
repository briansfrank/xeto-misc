//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2023  Brian Frank  Creation
//

using util
using data
using haystack
using defc
using xetoTools

**
** OAP compiler shell command line interface program
**
class DocToc : XetoCmd
{
  override Str name() { "doc-toc" }

  override Str summary() { "Generate xeto lib doc table of contents to JSON file" }

  @Opt { help = "Output file (default to stdout)" }
  File? out

  @Arg { help = "Lib to compile into table of contents" }
  Str? lib

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto doc-toc ph.points")
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

    toc := genLib(lib)

    withOut(this.out) |out|
    {
      env.print(toc, out, env.dict1("json", env.marker))
    }
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Generate
//////////////////////////////////////////////////////////////////////////

  private Dict genLib(DataLib lib)
  {
    initSpecs(lib)
    initNamespace

    acc := Str:Obj[:] { ordered = true }
    acc.addNotNull("Specs",  genSpecs(lib))
    acc.addNotNull("Equip",  genEquips(lib))
    acc.addNotNull("Points", genPoints(lib))
    return env.dict(acc)
  }

  private Void initSpecs(DataLib lib)
  {
    acc := DataSpec[,]
    lib.slots.each |x|
    {
      if (x.meta.has("nodoc")) return
      acc.add(x)
    }
    this.specs = sort(acc)
  }

  private Void initNamespace()
  {
    this.ns = DefCompiler().compileNamespace
  }

  private Obj? genSpecs(DataLib lib)
  {
    toLeafs(specs)
  }

//////////////////////////////////////////////////////////////////////////
// Equips (by taxonomy leafs)
//////////////////////////////////////////////////////////////////////////

  private Obj? genEquips(DataLib lib)
  {
    equips := findAllHas("equip")
    if (equips.isEmpty) return null

    return toSpecFolders(equipFolders, equips)
  }

  private DataSpec[] equipFolders()
  {
    acc := DataSpec[,]
    env.lib("ph").slots.each |x|
    {
      if (x.meta.missing("abstract") && x.slots.has("equip"))
        acc.add(x)
    }
    return sort(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  private Obj? genPoints(DataLib lib)
  {
    points := findAllHas("point")
    if (points.isEmpty) return null

    acc := Str:Obj[:] { ordered = true }

    // walk thru all choice subtypes
    allChoices := ns.subtypes(ns.def("choice")).sort
    allChoices.each |choice|
    {
      // a couple of these don't make sense since they overlap pointSubject
      if (choice.has("of") && choice.name != "pointSubject") return

      // walk thru all choice items (subtypes or of)
      accByChoice:= Str:Obj[:] { ordered = true }
      choiceItems := choiceItems(choice).sort
      choiceItems.each |item|
      {
        // if we have matching points then add them
        matches := points.findAll |x| { isDefMatch(item, x) }
        if (matches.isEmpty) return
        accByChoice[item.name] = toLeafs(matches)
      }
      if (accByChoice.isEmpty) return
      acc[choice.name] = env.dict(accByChoice)
    }

    if (acc.size == 1) return acc[acc.keys.first]
    return env.dict(acc)
  }

  private Def[] choiceItems(Def choice)
  {
    of := choice["of"] as Symbol
    if (of != null)
      return ns.findDefs |x| { ns.fits(x, ns.def(of.toStr)) }
    else
      return ns.subtypes(choice)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Obj? toSpecFolders(DataSpec[] folders, DataSpec[] specs)
  {
    acc := Str:Obj[:] { ordered = true }
    folders.each |folder|
    {
      tags := Str[,]
      folder.slots.each |x| { if (x.isMarker) tags.add(x.name) }

      matches := specs.findAll |x| { tags.all |tag| { x.slots.has(tag) } }
      if (matches.isEmpty) return
      acc[folder.name] = toLeafs(matches)
    }
    if (acc.size == 1) return acc[acc.keys.first]
    return env.dict(acc)
  }

  private Bool isDefMatch(Def def, DataSpec spec)
  {
    s := def.symbol
    if (s.type.isTag) return spec.slots.has(s.name)
    if (s.type.isConjunct)
    {
      for (i:=0; i<s.size; ++i)
        if (spec.slots.missing(s.part(i))) return false
      return true
    }
    return false
  }

  private DataSpec[] findAllHas(Str tag)
  {
    specs.findAll |x| { x.slots.has(tag) }
  }

  private DataSpec[] sort(DataSpec[] specs)
  {
    specs.sort |a, b| { a.name <=> b.name }
  }

  private Str[] toLeafs(DataSpec[] specs)
  {
    specs.map |x->Str| { x.name }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  DataSpec[]? specs
  Namespace? ns
}


