import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'todo_view_model.dart';
import 'todo_state.dart';
import 'stats_page.dart';
import 'search_page.dart';

class TodoViewModelFactory with ViewModelFactory<TodoViewModel> {
  @override
  TodoViewModel build() => TodoViewModel();

  @override
  String? key() => 'shared-todo-viewmodel';
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage>
    with ViewModelStateMixin<TodoPage> {
  final _textController = TextEditingController();
  final _categoryController = TextEditingController();

  TodoViewModel get todoVM =>
      watchViewModel<TodoViewModel>(factory: TodoViewModelFactory());

  @override
  void dispose() {
    _textController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsPage()),
              );
            },
          ),
          if (todoVM.state.items.any((item) => item.completed))
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              onPressed: todoVM.clearCompleted,
              tooltip: l10n.clearCompleted,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: l10n.addTodoHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    hintText: l10n.categoryHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addTodo),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                todoVM.state.items.isEmpty
                    ? Center(child: Text(l10n.noTodos))
                    : ListView.builder(
                      itemCount: todoVM.state.items.length,
                      itemBuilder: (context, index) {
                        final item = todoVM.state.items[index];
                        return Dismissible(
                          key: Key(item.id),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16.0),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => todoVM.removeTodo(item.id),
                          child: ListTile(
                            leading: Checkbox(
                              value: item.completed,
                              onChanged: (_) => todoVM.toggleTodo(item.id),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                decoration:
                                    item.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                              ),
                            ),
                            subtitle:
                                item.category != null
                                    ? Text(item.category!)
                                    : null,
                            onTap: () => todoVM.toggleTodo(item.id),
                            onLongPress: () {
                              _showEditDialog(context, item);
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  void _addTodo() {
    final title = _textController.text;
    final category = _categoryController.text;

    if (title.isNotEmpty) {
      todoVM.addTodo(title, category: category.isNotEmpty ? category : null);
      _textController.clear();
      _categoryController.clear();
    }
  }

  void _showEditDialog(BuildContext context, TodoItem item) {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController(text: item.title);
    final categoryController = TextEditingController(text: item.category ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.editTodo),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: l10n.editTodoTitle),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(labelText: l10n.editTodoCategory),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    todoVM.editTodo(
                      item.id,
                      titleController.text,
                      newCategory:
                          categoryController.text.isNotEmpty
                              ? categoryController.text
                              : null,
                    );
                    Navigator.pop(context);
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          ),
    );
  }
}
