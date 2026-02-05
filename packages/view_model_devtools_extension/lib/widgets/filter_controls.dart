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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: filter,
              decoration: const InputDecoration(
                labelText: 'Filter',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All ViewModels')),
                DropdownMenuItem(value: 'active', child: Text('Active Only')),
                DropdownMenuItem(value: 'disposed', child: Text('Disposed')),
              ],
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: realTimeUpdate,
              onChanged: (_) => onRealTimeToggle(),
              contentPadding: EdgeInsets.zero,
              title: const Text('Real-time Update'),
              dense: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
