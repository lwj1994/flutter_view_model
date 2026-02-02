import 'package:flutter/material.dart';
import 'package:todo_list/l10n/app_localizations.dart';
import 'package:view_model/view_model.dart';

import '../todo_state.dart';
import '../todo_view_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with ViewModelStateMixin<SearchPage> {
  final _searchController = TextEditingController();
  String? _selectedCategory;

  TodoViewModel get todoVM =>
      viewModelBinding.watchCached<TodoViewModel>(
        key: 'shared-todo-viewmodel',
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = todoVM.getStats();
    final filteredItems = _getFilteredItems();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTodos)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchTodosHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (stats.categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: Text(l10n.all),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ...stats.categories.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategory =
                                      _selectedCategory == category
                                          ? null
                                          : category;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(child: Text(l10n.noMatchingTodos))
                : ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return ListTile(
                        leading: Checkbox(
                          value: item.completed,
                          onChanged: (_) => todoVM.toggleTodo(item.id),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            decoration: item.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle:
                            item.category != null ? Text(item.category!) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => todoVM.removeTodo(item.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<TodoItem> _getFilteredItems() {
    List<TodoItem> items = todoVM.state.items;

    if (_selectedCategory != null) {
      items = todoVM.getItemsByCategory(_selectedCategory!);
    }

    if (_searchController.text.isNotEmpty) {
      items = items
          .where(
            (item) =>
                item.title.toLowerCase().contains(
                      _searchController.text.toLowerCase(),
                    ) ||
                (item.category?.toLowerCase().contains(
                          _searchController.text.toLowerCase(),
                        ) ??
                    false),
          )
          .toList();
    }

    return items;
  }
}
