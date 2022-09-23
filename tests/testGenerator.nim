import slinim
import std/[
  unittest
]
importSlint("todo.slint", todo)

test "Making todo":
  var tx = TodoItem(checked: false, title: slint"hello")
  check tx.checked == false
  check tx.title == "hello"
  
proc main() = 
  let app = MainWindow.create()
  app.show()
  test "Get basic property":
    check app.someNum == 9
  test "Set basic property":
    app.someNum = 29
    check app.someNum == 29
    app.someNum = 9
  app.hide()

main()
