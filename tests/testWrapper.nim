import slinim

import std/[
  unittest
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
