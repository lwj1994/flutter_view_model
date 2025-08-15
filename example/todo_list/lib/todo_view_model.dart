import 'package:view_model/view_model.dart';

import 'todo_state.dart';

class TodoViewModel extends StateViewModel<TodoState> {
  TodoViewModel() : super(state: const TodoState());

  void addTodo(String title, {String? category}) {
    if (title.trim().isEmpty) {
      return;
    }

    final newTodo = TodoItem(
      id: DateTime.now().toString(),
      title: title.trim(),
      category: category,
    );

    setState(state.copyWith(items: [...state.items, newTodo]));
  }

  void toggleTodo(String id) {
    final updatedItems = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(completed: !item.completed);
      }
      return item;
    }).toList();

    setState(state.copyWith(items: updatedItems));
  }

  void removeTodo(String id) {
    setState(
      state.copyWith(
        items: state.items.where((item) => item.id != id).toList(),
      ),
    );
  }

  void editTodo(String id, String newTitle, {String? newCategory}) {
    if (newTitle.trim().isEmpty) return;

    final updatedItems = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(
          title: newTitle.trim(),
          category: newCategory ?? item.category,
        );
      }
      return item;
    }).toList();

    setState(state.copyWith(items: updatedItems));
  }

  void clearCompleted() {
    setState(
      state.copyWith(
        items: state.items.where((item) => !item.completed).toList(),
      ),
    );
  }

  // New: Filter by category
  List<TodoItem> getItemsByCategory(String? category) {
    if (category == null) return state.items;
    return state.items.where((item) => item.category == category).toList();
  }

  // New: Search functionality
  List<TodoItem> searchItems(String query) {
    final lowercaseQuery = query.toLowerCase();
    return state.items
        .where(
          (item) =>
              item.title.toLowerCase().contains(lowercaseQuery) ||
              (item.category?.toLowerCase().contains(lowercaseQuery) ?? false),
        )
        .toList();
  }

  // New: Get statistics
  TodoStats getStats() {
    final total = state.items.length;
    final completed = state.items.where((item) => item.completed).length;
    final categories = state.items
        .map((item) => item.category)
        .where((category) => category != null)
        .toSet();

    return TodoStats(
      total: total,
      completed: completed,
      remaining: total - completed,
      categories: categories.cast<String>().toList(),
    );
  }
}

class TodoStats {
  final int total;
  final int completed;
  final int remaining;
  final List<String> categories;

  const TodoStats({
    required this.total,
    required this.completed,
    required this.remaining,
    required this.categories,
  });
}
