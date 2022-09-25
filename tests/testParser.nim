import slinim/parser {.all.}
import std/[
  os,
  osproc,
  unittest,
  strformat,
  sequtils
]

setCurrentDir("tests")
for file in walkFiles("*.slint"):
  echo file
  let headerFile = fmt"{file.splitFile().name}.h"
  if not fileExists(headerFile):
    assert execCmd(fmt"slint-compiler {file} -o {headerFile}") == 0

suite "Utils":
  test "Correctly parse basic type":
    check parseSlintType("int").kind == Int

  test "Correctly parse struct":
    let kind = parseSlintType("TodoItem")
    check kind.kind == Structure
    check kind.name == "TodoItem"

  test "Correctly parse Model type":
    let kind = parseSlintType("std::shared_ptr<slint::Model<TodoItem>>")
    check kind.kind == Model
    let inner = kind.inner
    check inner.kind == Structure
    check inner.name == "TodoItem"

  test "Correctly parse 2D Model type":
    let kind = parseSlintType("std::shared_ptr<slint::Model<std::shared_ptr<slint::Model<TodoItem>>>>")
    check kind.kind == Model
    var inner = kind.inner
    check inner.kind == Model
    inner = inner.inner
    check inner.kind == Structure
    check inner.name == "TodoItem"

suite "Basic app":
  let app = parseHeader("hello.h")
  test "Find app name":
    check app.root.name == "HelloWorld"

  test "Find properties":
    check app.root.properties.len == 0

suite "Todo App":
  let app = parseHeader("todo.h")
  test "Find app name":
    check app.root.name == "MainWindow"

  test "Find properties":
    let expected = @[
      initProperty("main", initStructureType("TodoItem")),
      initProperty("someNum", Int),
      initProperty("todo_model", initModelType(initStructureType("TodoItem")))
    ]
    check app.root.properties == expected

  test "Find callbacks":
    let expected = @[
      initCallback("popup_confirmed"),
      initCallback("remove_done"),
      initCallback("show_confirm_popup"),
      initCallback("todo_added", @[
        initType(String)
      ]),
      initCallback("multiple_params", @[
        initType(String),
        initType(Int)
      ])
    ]
    for callback in expected:
      check callback in app.root.callbacks

  test "Find TodoItem struct":
    check app.structs.len == 1
    check app.structs[0] == initStruct(
      "TodoItem",
      @[
        initProperty("checked", Bool),
        initProperty("title", String),
      ]
    )

suite "Extras":
  let app = parseHeader("callback.h")
  test "Callback with return type":
    check app.root.callbacks == @[
      initCallback("hello", @[initType(Int)], initType(String))
    ]
