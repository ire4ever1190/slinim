import slinim/[
  parser,
  wrapper,
  generator
]

import std/[
  strformat,
  os
]

# Slint requires modern compilier and for slint to be linked
{.passC: "-std=c++20".}
{.passL: "-lslint_cpp".}

export parser, generator, wrapper

when isMainModule:
  # Code for slint -> Nim binding generator
  import clapfn
  import std/[
    tables,
    osproc,
    strutils,
    streams
  ]
  # Setup argument parser
  var argParser = ArgumentParser(programName: "slinim", fullName: "Slinim",
                                 description: "Creates bindings to slint app for Nim",
                                 version: "0.1.0",
                                 author: "Jake Leahy <jake@leahy.dev>")
  argParser.addRequiredArgument(name = "inFile", help = "Input file (.slint UI file")
  argParser.addRequiredArgument(name = "outFile", help = "Nim output file (use - for stdout)")
  let args = argParser.parse()
  # Use args to make the bindigns
  let
    slintFile = args["inFile"]
    outputFile = args["outFile"]
    headerFile = slintFile.replace(".slint", ".h")
  # Create the header file. Also make the vtable inline while we are at it
  var headerProcess = startProcess("slint-compiler", args = [slintFile, "--style", "fluent"], options = {poStdErrToStdOut, poUsePath})
  var headerFileStream = newFileStream(headerFile, fmWrite)
  for line in headerProcess.lines:
    if line.startsWith("const slint::private_api::ComponentVTable"):
      let newLine = line.replace("const slint::private_api::ComponentVTable", "inline const slint::private_api::ComponentVTable")
      headerFileStream.writeLine newLine
    else:
      headerFileStream.writeLine line
  close headerFileStream
  assert headerProcess.waitForExit() == 0
  # Make bindings
  let 
    info = parseHeader(headerFile)
    bindings = makeBindFile(info, headerFile)
  # write Nim bindings
  if outputFile == "-":
    echo bindings
  else:
    outputFile.writeFile(bindings)
