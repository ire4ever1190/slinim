import slinim
import std/[
  unittest,
  tables
]
importSlint("todo.slint")
# import todo
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
  app.hide()

main()
