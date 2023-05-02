#! /usr/bin/env fan
//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 May 2023  Brian Frank  Creation
//

using build

**
** Build: opac
**
class Build : BuildPod
{
  new make()
  {
    podName = "oapc"
    summary = "Ontology Alignment Project compiler to xeto"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com//briansfrank/proto"]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "util @{fan.depend}",
               "yaml @{fan.depend}",
               "data @{hx.depend}",
               ]
    srcDirs = [`fan/`]
  }
}