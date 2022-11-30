##[
  Wraps functions/types for slint
]##

import std/options

{.pragma: slintHeader header: "slint.h", nodecl.}

type
  ComponentHandle*[T] {.slintHeader, importcpp: "slint::ComponentHandle".} = object
    ## Handle to a component in the slint application. Only used for the main application

  ComponentWeakHandle*[T] {.slintHeader, importcpp: "slint::ComponentHandle".} = object
    ## Weak reference to a component
    
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

  SlintColor* {.slintHeader, importcpp: "slint::Color".} = object
    ## Represents an RGBA color

  Model*[T] {.slintHeader, importcpp: "std::shared_ptr<slint::Model<'0>>".} = object
  
  VectorModel*[T] {.slintHeader, importcpp: "std::shared_ptr<slint::VectorModel<'0>>".} = object
    ## Acts like an array in slint. Must be initialised manually
    # I imported it with the std::shared_ptr since it is usually used with it

  Optional[T] {.header: "<optional>", importcpp: "std::optional".} = object

  Image* {.slintHeader, importcpp: "slint::Image".} = object
  
    
using comp: ComponentHandle
using window: WindowRef
using str: SlintString
using color: SlintColor
using model: Model

#
# Optional
#

proc isSome(o: Optional): bool {.header: "<optional>", importcpp: "#.has_value()".}
proc get[T](o: Optional[T]): T {.header: "<optional>", importcpp: "*#".}

#
# Component Handle
#

proc weakHandle[T](c: ComponentHandle[T]): ComponentWeakHandle[T] {.slintHeader, importcpp: "ComponentWeakHandle(@)".}
  ## Creates a new weak handle from an existing handle

proc rawLock[T](c: ComponentWeakHandle[T]): Optional[ComponentHandle[T]] {.slintHeader, importcpp: "#.lock()".}
proc lock[T](c: ComponentWeakHandle): Option[ComponentHandle[T]] =
  ## Gets a strong handle from weak. Is `none()` if the component the weak handle points to still exists
  let handle = c.rawLock()
  if handle.isSome():
    result = some handle

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

proc `=copy`(str: var SlintString, other: SlintString) = discard
proc `=destroy`(str: var SlintString) = discard

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

func `$`*(str): string {.inline.} = $str.data

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

#
# Model
#

func newVectorModel*[T](): VectorModel[T] {.slintHeader, importcpp: "std::make_shared<slint::VectorModel<'*0>>()".}
  ## Initialises a new model

func len*(model: Model | VectorModel): cint {.slintHeader, importcpp: "#->row_count()".}
  ## Returns the number of items in the model
  
func rawget[T](model: Model[T] | VectorModel[T], i: cint): Optional[T] {.slintHeader, importcpp: "#->row_data(@)".}

func get*[T](model: Model[T] | VectorModel[T]; i: cint): Option[T] =
  ## Gets the item from the model at index `i`. If it doesn't exist then returns `none(T)`
  # Converts from C++ Optional[T] to Nim Option[T]
  var item = model.rawget(i)
  if item.isSome:
    result = some item.get()
    
func `[]`*[T](model: Model[T] | VectorModel[T], i: cint): T =
  ## Gets the item from the moedl at index `i`. Throws index defect if out of range
  rangeCheck i < model.len
  result = model.rawget(i).get()

func `[]=`*[T](model: var Model[T] | var VectorModel[T], i: cint, item: T) {.slintHeader, importcpp: "#->set_row_data(@)".}
  ## Sets the item at index `i` to `item`

func delete*(model: var VectorModel, i: cint) {.slintHeader, importcpp: "#->erase(@)".}
  ## Deletes the item at index `i`. Shares same semantics as Nim's `delete`

func insert*[T](model: var VectorModel[T], i: csize_t, item: T) {.slintHeader, importcpp: "#->insert(@)".}

func add*[T](model: var VectorModel[T], item: T) {.slintHeader, importcpp: "#->push_back(@)".}
  ## Adds an item to the model

func newVectorModel*[T](items: openArray[T]): VectorModel[T] =
  ## Initialises a new model from existing items.
  # This adds items individually. I was unable to bind to the vector constructor the c code uses
  result = newVectorModel[T]()
  for item in items:
    result &= item

iterator items*[T](model: Model[T]): T =
  ## Iterates through items in the model
  for i in 0..<model.len:
    yield model[i]

func contains*[T](model: Model[T], looking: T): bool =
  ## Returns true if item appears in the model
  for item in model:
    if item == looking:
      return true

#
# Image
#

proc initImage*(path: SlintString): Image {.importcpp: "slint::Image::load_from_path(@)".}
  
