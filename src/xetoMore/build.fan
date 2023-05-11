#! /usr/bin/env fan
//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2023  Brian Frank  Creation
//

using build

**
** Build: xetoMore
**
class Build : BuildPod
{
  new make()
  {
    podName = "xetoMore"
    summary = "More xeto command line tools"
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
               "data @{hx.depend}",
               "haystack @{hx.depend}",
               "defc @{hx.depend}",
               "xetoTools @{hx.depend}",
               ]
    srcDirs = [`fan/`]

    index = ["xeto.cmd":"xetoMore::DocToc"]
  }
}