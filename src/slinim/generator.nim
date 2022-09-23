import parser

import std/[
  os,
  strformat,
  times,
  osproc,
  macros,
  sequtils,
  strutils
]

template lambda*(body: untyped): proc () {.cdecl.} =
  {.emit: """
    [&] () {
      `body`
    }
  """.}

func generate*(callback: Callback, outFile: var string) =
  ## Genereates code to register a callback
  # Create list of parameters
  var 
    i = 0
    params = ""
  while i < callback.params.len:
    if i > 0:
      params &= ", "
    params &= char('a'.ord + i) & ": " & $callback.params[i]
    inc i
  # Stores common strings
  let
    procName = fmt"on_{callback.name}"
    closureHandler = fmt"handler_{callback.name}"
    
  # Add functions to take both normal proc and a closure
  outFile &= fmt"""
func {procName}*(comp; x: proc ({params}) {{.cdecl.}}) {{.appHeader, importcpp: "#->on_{callback.name}(@)"}}
"""

func generate*(property: Property, outFile: var string) =
  ## Generates getter/setter for a property
  let 
    kindStr = $property.kind
    getter = fmt"get_{property.name}"
    setter = fmt"set_{property.name}"
    
  outFile &= fmt"""
proc {getter}*(comp): {kindStr} {{.appHeader, importcpp: "#->{getter}()".}}
proc {property.name}*(comp): {kindStr} {{.inline.}} = comp.{getter}()

proc {setter}*(comp; value: {kindStr}) {{.appHeader, importcpp: "#->{setter}(@)".}}
proc `{property.name}=`*(comp; value: {kindStr}) {{.inline.}} = comp.{setter}(value)
"""

func generate*(struct: SlintStruct, outFile: var string) =
  ## Generate the custom struct as a Nim object
  outFile &= fmt"""type {struct.name}* {{.appHeader, importcpp: "{struct.name}".}} = object"""
  outFile &= '\n'
  for property in struct.properties:
    outFile &= fmt"  {property.name}*: {property.kind}"
    outFile &= '\n'

proc makeBindFile*(info: SlintFile, headerFile: string): string =
  ##[
    Code generation happens here. The information parsed is turned into Nim code
    which can be written somewhere and then imported to enable running the slint app
  ]##
  let
    mainClass = info.root.name
    mainClassComp = mainClass & "Comp"
  # Generate the initial class functions
  result = fmt"""
import slinim

# Generated at {now()}

{{.pragma: appHeader header: "{headerFile}", nodecl.}}

type
  {mainClass}* {{.appHeader, importcpp.}} = object
  {mainClassComp}* {{.nodecl.}} = ComponentHandle[{mainClass}]
  
using root: {mainClass}
using comp: {mainClassComp}

proc show*(comp) {{.appHeader, importcpp: "#->show()".}}
  ## Shows the window
proc hide*(comp) {{.appHeader, importcpp: "#->hide()".}}
  ## Hides the window
proc run*(comp) {{.appHeader, importcpp: "#->run()".}}
  ## Shows the window, runs the event loop, then hides when that finishes
proc window*(comp): WindowRef {{.appHeader, importcpp: "#->window()".}}
  ## Gets reference to the window
proc create*(x: typedesc[{mainClass}]): {mainClassComp} {{.importcpp: "'*0::create()".}}
"""
  # Generate structs
  for struct in info.structs:
    struct.generate(result)
  # Generate properties
  for property in info.root.properties:
    property.generate(result)
  # Generate callbacks
  for callback in info.root.callbacks:
    callback.generate(result)

template importSlint*(slint: static[string], module: untyped): untyped =
  ## Generates the Nim bindings and imports them.
  ## 
  ## * **module**: Name to give to the nim module
  import os
  import macros
  static:
    const (path, fileName, ext) = slint.splitFile()
    const
      nimPath = getProjectPath() / fileName & ".nim"
      headerPath = getProjectPath() / fileName & ".h"
      slintPath = getProjectPath() / slint
    static:
      echo nimPath
      echo headerPath
    # TODO: Only rebuild if updated
    # Build the header file if needed
    {.hint: "Building header file...".}
    echo staticExec("slint-compiler -o " & headerPath & " " & slintPath)
    # Rebuild nim module if it doesn't exist or the header file is newer
    {.hint: "Building Nim bindings...".}
    echo staticExec(fmt"slinim " & headerPath & " " & nimPath)

  import module