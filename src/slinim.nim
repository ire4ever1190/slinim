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
  import std/tables
  var argParser = ArgumentParser(programName: "slinim", fullName: "Slinim",
                                 description: "Creates bindings to slint app for Nim",
                                 version: "0.1.0",
                                 author: "Jake Leahy <jake@leahy.dev>")
  argParser.addRequiredArgument(name = "inFile", help = "Input file (either .slint or generated .h)")
  argParser.addRequiredArgument(name = "outFile", help = "Nim output file (use - for stdout)")
  let args = argParser.parse()
  # Use args to make the bindigns
  let
    headerFile = args["inFile"]
    outputFile = args["outFile"]
    info = parseHeader(headerFile)
    bindings = makeBindFile(info, headerFile)
  if outputFile == "-":
    echo bindings
  else:
    outputFile.writeFile(bindings)
