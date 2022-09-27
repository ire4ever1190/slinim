import slinim
import std/[
  unittest,
  tables
]
importSlint("todo.slint")

test "Making todo":
  var tx = TodoItem(checked: false, title: slint"hello")
  check tx.checked == false
  check tx.title == "hello"

var called = false
  
proc main() = 
  block:
    let app = MainWindow.create()
    app.show()
    test "Get basic property":
      check app.someNum == 9
      
    test "Set basic property":
      app.someNum = 29
      check app.someNum == 29
      app.someNum = 9
      
    test "Get struct":
      let todo = app.main
      check:
        todo.title == "Finish this library"
        not todo.checked
        
    test "Set struct":
      let title = slint"New item"
      let newTodo = TodoItem(
        title: title,
        checked: true
      )
      # var tab = initTable[string, TodoItem]()
      # echo newTodo
      # tab["test "] = newTodo
      app.main = newTodo
      check app.main.title == newTodo.title

    test "Get model":
      let items = app.todoModel
      check:
        items.len == 8
        items[0] == TodoItem(
          title: slint"Implement the .slint file",
          checked: true
        )

    test "Normal handler":
      app.onPopUpConfirmed(proc () = called = true)
      app.popUpConfirmed()
      check called

    test "Closure handler":
      var l = 0
      app.onPopUpConfirmed() do ():
        l += 1
      app.popUpConfirmed()
      check l == 1
    app.hide()
main()
