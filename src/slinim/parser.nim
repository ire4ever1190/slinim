import std/[
  strutils,
  streams,
  strscans,
  parseutils,
  tables
]

type
  ParseState = enum
    ## Different states the parser can be in
    FindingStruct  # Looking for beginning of struct
    FindingRoot    # Looking for root class
    InStruct       # Parsing inside a struct
    InClassPublic  # Inside the public section of the root class
    InClassPrivate # Inside the private section of the root class
    IgnoringClass  # Ignoring all items until end of class

  SlintKind* = enum
    ## Different kind of types in slint
    Int
    Float
    Bool
    String
    Color
    Brush
    Image
    # Lengths are both floats
    # PhysicalLength
    # Length
    Duration
    # Angle
    Structure
    Model # Basically array

  SlintType* {.acyclic.} = ref object
    ## A type in slint
    case kind*: SlintKind
    of Model:
      inner*: SlintType
    of Structure:
      name*: string
    else: discard

  Property* = object
    ## Generate key/type property
    name*: string
    kind*: SlintType

  Callback* = object
    ## A callback that can be handled in the code
    name*: string
    params*: seq[SlintType]


  Application* = object
    ## The main application window
    name*: string
    properties*: seq[Property]
    callbacks*: seq[Callback]

  SlintStruct* = object
    ## A struct from slint
    name*: string
    properties*: seq[Property]

  SlintClass = object
    ## Different from a struct, this is the raw class that is parsed from the file.
    ## Used for storing information while parsing
    privateCallbacks: seq[Callback] # Type information is only stored in private section
    callbacks: seq[Callback] # Used to only keep private callbacks that appear here
    properties: seq[Property]

  SlintFile* = object
    ## The information about a file
    root*: Application
    structs*: seq[SlintStruct]

const
  classEndToken = "};"
  root_prefix = "root_1"

func `$`*(x: SlintType): string =
  case x.kind:
  of Int: "cint"
  of Float: "cfloat"
  of Bool: "bool"
  of String: "SlintString"
  of Model:
    "seq[" & $x.inner & "]"
  of Structure:
    x.name
  else:
    $x.kind

func `==`*(a, b: SlintType): bool =
  if a.kind == Model and b.kind == Model:
    a.inner == b.inner
  else:
    a.kind == b.kind

func `==`*(a, b: Callback): bool =
  result = a.name == b.name and a.params == b.params

func initType*(kind: SlintKind): SlintType =
  ## Creates a new type
  result = SlintType(kind: kind)

func initModelType*(inner: SlintType): SlintType =
  ## Helper to make model type
  result = SlintType(
    kind: Model,
    inner: inner
  )

func initStructureType*(name: string): SlintType =
  ## Helper to make structure type
  result = SlintType(
    kind: Structure,
    name: name
  )

func initProperty*(name: string, kind: SlintKind): Property = 
  ## Creates a new property
  result.name = name
  result.kind = initType(kind)

func initProperty*(name: string, kind: SlintType): Property = 
  ## Creates a new property
  result.name = name
  result.kind = kind

func parseSlintType(kind: string): SlintType =
  ## Parses the type of the slint item from the C++ type
  result = SlintType(kind: 
      case kind
      of "int": Int
      of "float": Float
      of "bool": Bool
      of "slint::SharedString": String
      of "slint::Color": Color
      of "slint::Brush": Brush
      of "slint::Image": Image
      of "std::int64_t": Duration
      else:
        # Now we need to tell apart models and structs
        if kind.startsWith("std::shared_ptr<"): Model
        else: Structure
  )
  # Get extra information if needed
  case result.kind
  of Model:
    result.inner = parseSlintType(kind["std::shared_ptr<slint::Model<".len ..< ^2])
  of Structure:
    result.name = kind
  else: discard
  
func initProperty*(name: string, kind: string): Property =
  ## Creates a new property. Parses kind from C++ type string
  result.name = name
  result.kind = parseSlintType(kind)
  

func initCallback*(name: string, params: seq[SlintType] = @[]): Callback =
  ## Creates a new callback
  result.name = name
  result.params = params

func initStruct*(name: string, properties: seq[Property]): SlintStruct = 
  ## Creates a new struct
  result.name = name
  result.properties = properties
  
proc parseHeader*(file: string): SlintFile =
  ## Parses information from header
  var strm = newFileStream(file)
  if strm == nil:
    raise (ref IOError)(msg: "Couldn't open: " & file)
  # Data needed across lines
  var
    currStruct: SlintStruct
    line: string
    state = FindingStruct
    foundCallbacks: Table[string, Callback]
    
  # Parse the file
  while strm.readLine(line):
    case state
    of FindingStruct:
      # In this state we are looking for the beginning of a struct
      # or the name of the root class. Once the name is found that means we 
      # are at the end of the structs
      var className: string
      if line.scanf("class $w;", className):
        # Structs have now ended, we have found name of the root class
        result.root.name = className
        state = FindingRoot
      elif line.scanf("class $w {", className):
        currStruct = SlintStruct.default
        currStruct.name = className
        state = InStruct
    of InStruct:
      # Now inside struct, we need to parse its properties
      if line == classEndToken:
        result.structs &= currStruct
        state = FindingStruct
        continue
      var i = line.skipWhitespace()
      var 
        kind: string
        name: string
      i += line.parseUntil(kind, Whitespace, i) + 1
      # Structs start with a "public:" and end with a == operator. Everything else is an operator
      # We ignore anything that isn't a property
      if kind in ["public:", "friend"]: continue
      i += line.parseUntil(name, ';', i)
      currStruct.properties &= initProperty(name, kind)
    of FindingRoot:
      # We are now trying to find the root class
      var className: string
      if line.scanf("class $w {", className):
        if className == result.root.name:
          # We have found the main class, now start parsing the insides
          # All classes are generated by slint to start as public
          state = InClassPublic
    of InClassPublic:
      # In the public section of the root. We use the info found here
      # to see if we are meant to generate bindings or not.
      #
      # Getters are generated before setters so we get the information from them 
      # (This decision is basically arbitary, but is bit easier)
      let strippedLine = line.strip()
      var
        ident, kind: string
        callbackName: string
      if strippedLine == "private:":
        state = InClassPrivate
      elif strippedLine.scanf("inline auto get_$w () const -> $*;", ident, kind):
        # Sucessfully parsed getter
        result.root.properties &= initProperty(ident, kind)
      elif strippedLine.scanf("template<typename Functor> inline auto on_$w", callbackName):
        result.root.callbacks &= foundCallbacks[callbackName]
    of InClassPrivate:
      # In the private section of the root. This is the only part that has type info
      # for callbacks so we need to get them from here
      let strippedLine = line.strip()
      var params, callbackName: string
      if strippedLine == "public:":
        state = InClassPublic
        continue
      elif strippedLine.scanf("slint::private_api::Callback<void($*)> root_1_$w", params, callbackName):
        # Found call back, get properties then add to found list
        var callback = Callback(name: callbackName)
        for param in params.split(", "):
          if param != "":
            callback.params &= parseSlintType(param)
        foundCallbacks[callbackName] = callback
    of IgnoringClass:
      # Not particularrly trying to find anything, we can safely ignore
      if line == classEndToken:
        state = FindingRoot
    

