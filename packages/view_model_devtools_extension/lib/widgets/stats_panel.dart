import 'package:flutter/material.dart';

import '../services/view_model_service.dart';

class StatsPanel extends StatelessWidget {
  final DependencyStats stats;

  const StatsPanel({super.key, required this.stats});

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
          children: [
            _StatRow(
              label: 'Total',
              value: stats.totalViewModels.toString(),
              icon: Icons.view_module,
              color: Colors.blue,
            ),
            const SizedBox(height: 8),
            _StatRow(
              label: 'Active',
              value: stats.activeViewModels.toString(),
              icon: Icons.play_circle_filled,
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            _StatRow(
              label: 'Disposed',
              value: stats.disposedViewModels.toString(),
              icon: Icons.delete_outline,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}
