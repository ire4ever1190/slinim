import slinim

importSlint("todo.slint")


proc main() =
  var todoModel = newVectorModel[TodoItem]([
    TodoItem(checked: true, title: slint"Implement the .slint file"),
    TodoItem(checked: false, title: slint"Do the Rust part"),
    TodoItem(checked: true, title: slint"Make the C++ code"),
    TodoItem(checked: false, title: slint"Write some JavaScriptCode"),
    TodoItem(checked: false, title: slint"Test the application"),
    TodoItem(checked: false, title: slint"Ship to customer"),
    TodoItem(checked: false, title: slint"???"),
    TodoItem(checked: false, title: slint"Profit")
  ])
  let demo = MainWindow.create()
  var w = initWeakHandle(demo)
  demo.todoModel = todoModel

  demo.onTodoAdded() do (s: SlintString):
    todoModel &= TodoItem(checked: false, title: s)

  demo.onRemoveDone() do ():
    for i in countdown(todoModel.len - 1, 0, 1):
      if todoModel[i].checked:
        todoModel.delete(i)

  demo.onPopUpConfirmed() do ():
    withLock w, handle:
      handle.window().hide()
# 
  demo.window.onCloseRequested() do () -> CloseRequestResponse:
    for item in todoModel:
      if not item.checked:
        withLock w, handle: handle.showConfirmPopUp()
        return KeepWindowShown
    return HideWindow

  demo.run()

main()
  
