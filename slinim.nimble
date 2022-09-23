# Package

version       = "0.1.0"
author        = "Jake Leahy"
description   = "Wrapper around slint-ui (https://slint-ui.com)"
license       = "MIT"
srcDir        = "src"
bin = @["slinim"]
installExt = @["nim"]

# Dependencies

requires "nim >= 1.6.0"
requires "clapfn == 1.0.1"
