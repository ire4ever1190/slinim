import slinim/[
  parser,
  wrapper,
  generator
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
    streams,
    sha1,
    os,
    strformat
  ]
  # Setup argument parser
  var argParser = ArgumentParser(programName: "slinim", fullName: "Slinim",
                                 description: "Creates bindings to slint app for Nim",
                                 version: "0.1.0",
                                 author: "Jake Leahy <jake@leahy.dev>")
  argParser.addRequiredArgument(name = "inFile", help = "Input file (.slint UI file")
  argParser.addRequiredArgument(name = "outFile", help = "Nim output file (use - for stdout, tmp for a temporary file (prints path))")
  argParser.addStoreArgument(shortName="-s", longName="--style", default="fluent", 
                             help="Specifies the style to use for slint", usageInput="style")
  let args = argParser.parse()
  # Use args to make the bindigns
  let
    slintFile = args["inFile"]
    outputFile = args["outFile"]
    headerFile = slintFile.replace(".slint", ".h")
  # Create the header file. Also make the vtable inline while we are at it
  var headerProcess = startProcess("slint-compiler", args = [slintFile, "--style", args["style"]], options = {poStdErrToStdOut, poUsePath})
  var headerFileStream = newFileStream(headerFile, fmWrite)
  # Also generate hash while we are at it
  var hash = newSha1State()
  for line in headerProcess.lines:
    hash.update(line)
    if line.startsWith("const slint::private_api::ComponentVTable"):
      let newLine = line.replace("const slint::private_api::ComponentVTable", "inline const slint::private_api::ComponentVTable")
      headerFileStream.writeLine newLine
    else:
      headerFileStream.writeLine line
  
  close headerFileStream
  if headerProcess.waitForExit() != 0:
    echo headerProcess.outputStream().readAll()
  # Make bindings
  let 
    info = parseHeader(headerFile)
    bindings = makeBindFile(info, headerFile)
  # write Nim bindings
  if outputFile == "-":
    echo bindings
  elif outputFile == "tmp":
    let outputFile = getTempDir() / "slinim_" & $SecureHash(hash.finalize()) & ".nim"
    let nimFile = slintFile.replace(".slint", ".nim")
    outputFile.writeFile(bindings)
    echo outputFile
    # Check we aren't overwriting anything important first
    if not nimFile.fileExists() or nimFile.getFileInfo().size <= 75:
      nimFile.writeFile(fmt"""include "{outputFile}" """)
    else:
      stderr.writeLine("Output file already exists")
      quit 1
  else:
    outputFile.writeFile(bindings)
else:
  when not defined(cpp):
    {.error: "Slinim requires C++ backend".}
