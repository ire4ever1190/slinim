import slinim

import std/[
  unittest,
  options
]

suite "String":
  test "Make string":
    let s = slint"Hello world"
    check s.data == "Hello world"

  test "Iterator":
    let s = slint"Hello world"
    var output: string
    for c in s:
      output &= c
    check output == "Hello world"

  test "startsWith":
    let s = slint"Hello world"
    check s.startsWith("Hello")

suite "Model":
  test "Adding to model":
    var model = newVectorModel[int]()
    model &= 9
    check:
      model.len == 1
      model[0] == 9

  test "Item out of range":
    var model = newVectorModel[int]()
    expect RangeDefect:
      discard model[0]
    check model.get(0).isNone()

  test "Getting optional in range":
    var model = newVectorModel[int]()
    model &= 9
    check model.get(0).get() == 9
