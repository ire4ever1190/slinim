##[
  Wraps functions/types for slint
]##

{.pragma: slintHeader header: "slint.h", nodecl.}

type
  ComponentHandle*[T] {.slintHeader, importcpp: "slint::ComponentHandle".} = object
    ## Handle to a component in the slint application. Only used for the main applicatino
    
  WindowRef* {.slintHeader, importcpp: "slint::Window&".} = object
    ## Reference to a window

  Size*[T] {.slintHeader, importcpp: "slint::Size<'*0>".} = object
    ## Generic structure to represent a 2D size
    width: T
    height: T

  LogicalSize* = Size[cfloat]
    ## Logical size used for internal sizes
  PhysicalSize* = Size[uint32]
    ## Physical size used for device screens

  SlintString* {.slintHeader, importcpp: "slint::SharedString".} = object
    ## String type used to interact with slint. Allows copies of the same memory to be passed
    ## around to make the program more efficient

  Color* {.slintHeader, importcpp: "slint::Color".} = object
    ## Represents an RGBA color

using comp: ComponentHandle
using window: WindowRef
using str: SlintString
using color: Color

#
# Window
#

proc show*(window) {.slintHeader, importcpp: "#.show()".}
  ## Shows the window
proc hide*(window) {.slintHeader, importcpp: "#.hide()".}
  ## Hides the window
proc size*(window): PhysicalSize {.slintHeader, importcpp: "#.size()".}
  ## Returns the size of the window on the screen, in physical screen coordinates and excluding a window frame (if present). 
proc `size=`*(window; size: PhysicalSize) {.slintHeader, importcpp: "#.set_size(@)".}
  ## Resizes the window to the specified size on the screen, in logical pixels and excluding a window frame (if present). 
proc `size=`*(window; size: LogicalSize) {.slintHeader, importcpp: "#.set_size(@)".}
  ## Resizes the window to the specified size on the screen, in logical pixels and excluding a window frame (if present). 

#
# Shared string
#

proc initSlintString*(data: cstring): SlintString {.slintHeader, importcpp: "slint::SharedString(@)", constructor.}
  ## Creates a new string to use with slint

proc slint*(data: string | cstring): SlintString {.inline.} = initSlintString(data)

proc data*(str): cstring {.slintHeader, importcpp: "#.data()".}
  ## Gets pointer to underlying string data. Only valid for lifetime of `SlintString`

proc begin*(str): ptr char {.slintHeader, importcpp: "#.begin()".}
  ## Returns the first character in the string

proc `end`*(str): ptr char {.slintHeader, importcpp: "#.end()".}
  ## Returns the end character in the string

proc empty*(str): bool {.slintHeader, importcpp: "#.empty()".}
  ## Returns true if string is empty

proc add*(str: var SlintString, data: cstring) {.slintHeader, importcpp: "# += @"}
  ## Appends another string to the string

proc startsWith*(str; prefix: cstring): bool {.slintHeader, importcpp: "#.starts_with(@)".}
  ## Returns true if string starts with prefix

proc endsWith*(str; suffix: cstring): bool {.slintHeader, importcpp: "#.ends_with(@)".}
  ## Returns true if string ends with suffix

proc assign*(str: var SlintString, newString: cstring) {.slintHeader, importcpp: "# = @".}

proc `==`*(str; other: cstring): bool {.inline.} =
  str == slint(other)

iterator items*(str): char =
  ## Iterates through characters in the string
  var begin = str.begin()
  let endChar = str.`end`()
  while begin != endChar:
    yield begin[]
    # Pointer maths to go to next character
    begin = cast[ptr char](cast[int](begin) + sizeof(char))

#
# Colour
#

proc red(color): byte {.slintHeader, importcpp: "#.red()".}
proc green(color): byte {.slintHeader, importcpp: "#.green()".}
proc blue(color): byte {.slintHeader, importcpp: "#.blue()".}
proc alpha(color): byte {.slintHeader, importcpp: "#.alpha()".}

