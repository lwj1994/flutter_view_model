import 'package:flutter/foundation.dart';

@immutable
class TodoItem {
  final String id;
  final String title;
  final bool completed;
  final String? category;

  const TodoItem({
    required this.id,
    required this.title,
    this.completed = false,
    this.category,
  });

  TodoItem copyWith({
    String? id,
    String? title,
    bool? completed,
    String? category,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          completed == other.completed &&
          category == other.category;

  @override
  int get hashCode => Object.hash(id, title, completed, category);
}

class TodoState {
  final List<TodoItem> items;
  final bool isLoading;
  final String? error;
  final String? selectedCategory;
  final String searchQuery;

  const TodoState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory,
    this.searchQuery = '',
  });

  TodoState copyWith({
    List<TodoItem>? items,
    bool? isLoading,
    String? error,
    String? selectedCategory,
    String? searchQuery,
  }) {
    return TodoState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoState &&
          runtimeType == other.runtimeType &&
          listEquals(items, other.items) &&
          isLoading == other.isLoading &&
          error == other.error &&
          selectedCategory == other.selectedCategory &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(items),
    isLoading,
    error,
    selectedCategory,
    searchQuery,
  );
}
