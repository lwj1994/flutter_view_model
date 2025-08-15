import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import '../todo_view_model.dart';
import 'l10n/app_localizations.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with ViewModelStateMixin<StatsPage> {
  TodoViewModel get todoVM =>
      watchViewModel<TodoViewModel>(key: 'shared-todo-viewmodel');

  @override
  Widget build(BuildContext context) {
    final stats = todoVM.getStats();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.todoStats)),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatCard(l10n.overview, [
            _buildStatItem(l10n.total, stats.total),
            _buildStatItem(l10n.completed, stats.completed),
            _buildStatItem(l10n.remaining, stats.remaining),
          ]),
          const SizedBox(height: 16),
          if (stats.categories.isNotEmpty)
            _buildStatCard(
              l10n.categoryStats,
              stats.categories.map((category) {
                final itemsInCategory =
                    todoVM.getItemsByCategory(category).length;
                final completedInCategory = todoVM
                    .getItemsByCategory(category)
                    .where((item) => item.completed)
                    .length;
                return _buildCategoryStats(
                  category,
                  itemsInCategory,
                  completedInCategory,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStats(String category, int total, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  backgroundColor: Colors.grey[200],
                ),
              ),
              const SizedBox(width: 8),
              Text('$completed/$total'),
            ],
          ),
        ],
      ),
    );
  }
}
