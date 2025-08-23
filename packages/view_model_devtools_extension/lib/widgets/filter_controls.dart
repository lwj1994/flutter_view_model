import 'package:flutter/material.dart';

class FilterControls extends StatelessWidget {
  final String filter;
  final bool realTimeUpdate;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onRealTimeToggle;
  final VoidCallback onRefresh;

  const FilterControls({
    super.key,
    required this.filter,
    required this.realTimeUpdate,
    required this.onFilterChanged,
    required this.onRealTimeToggle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Filter dropdown
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              value: filter,
              decoration: const InputDecoration(
                labelText: 'Filter',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All ViewModels')),
                DropdownMenuItem(value: 'active', child: Text('Active Only')),
                DropdownMenuItem(
                    value: 'disposed', child: Text('Disposed Only')),
              ],
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
          ),
          const SizedBox(width: 16),

          // Real-time update toggle
          Row(
            children: [
              Switch(
                value: realTimeUpdate,
                onChanged: (_) => onRealTimeToggle(),
              ),
              const SizedBox(width: 8),
              const Text('Real-time'),
            ],
          ),

          const Spacer(),

          // Refresh button
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
    );
  }
}
