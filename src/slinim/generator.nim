import parser

import std/[
  os,
  strformat,
  times,
  osproc,
  macros,
  sequtils,
  strutils,
  sha1
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
    lambdaParams = ""
    lambdaCall = ""
  while i < callback.params.len:
  
    if i > 0:
      params &= ", "
      lambdaParams &= ", "
    else:
      lambdaCall &= ", "
    let paramName = 'x' & $i
    params &= paramName & ": " & $callback.params[i]
    lambdaParams &= "auto " & paramName
    lambdaCall &= paramName
    inc i
  # Stores common strings
  let
    returnType = if callback.returnType.kind == Model:
        $callback.returnType & " | " & replace($callback.returnType, "Model[", "VectorModel[")
      else: $callback.returnType
  # Make list of parameters for closure lambda
  # Add functions to take both normal proc and a closure
  # To get closures working I did something a lil hacky
  # I make a lambda which gets a reference to the closure information, then calls the proc stored in the closure
  # Seems to work well, and means less weird magic needed
  # TODO: Support returns in closures
  outFile &= fmt"""
func on_{callback.name}*(comp; x: proc ({params}): {returnType} {{.cdecl.}}) {{.appHeader, importcpp: "#->on_{callback.name}(@)".}}
func on_{callback.name}*(comp; x: proc ({params}): {returnType} {{.closure.}}) {{.appHeader, importcpp: "#->on_{callback.name}([&]({lambdaParams}) {{auto& x = #; x.ClP_0(x.ClE_0{lambdaCall});}})".}}
proc {callback.name}*(comp; {params}): {returnType} {{.appHeader, importcpp: "#->invoke_{callback.name}(@)".}}
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
  if property.kind.kind == Model:
    # Allow the setter to take a VectorModel
    let vecKind = kindStr.replace("Model[", "VectorModel[")
    outFile &= fmt"""
proc {setter}*(comp; value: {vecKind}) {{.appHeader, importcpp: "#->{setter}(@)".}}
proc `{property.name}=`*(comp; value: {vecKind}) {{.inline.}} = comp.{setter}(value)
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

macro importSlint*(slint: static[string]): untyped =
  ## Generates the Nim bindings and imports them.
  ## 
  ## * **module**: Name to give to the nim module
  let (path, fileName, ext) = slint.splitFile()
  let
    headerPath = getProjectPath() / fileName & ".h"
    nimPath = getProjectPath() / fileName & ".nim"
    slintPath = getProjectPath() / slint
  {.hint: "Building Nim bindings...".}
  discard staticExec(fmt"slinim {slintPath} tmp")
  result = quote do:
    import `nimPath`
