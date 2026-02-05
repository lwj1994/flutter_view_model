import 'dart:math';

import 'package:flutter/material.dart';

import '../services/view_model_service.dart';

class ViewModelGraph extends StatelessWidget {
  final List<ViewModelInfo> viewModels;
  final DependencyGraphResult graph;
  final String filter;

  const ViewModelGraph({
    super.key,
    required this.viewModels,
    required this.graph,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final filteredViewModels = _filterViewModels();
    final vmMap = {for (final vm in filteredViewModels) vm.id: vm};
    final edges = graph.edges.where((edge) {
      return vmMap.containsKey(edge.to);
    }).toList();
    final bindingIds = edges.map((edge) => edge.from).toSet().toList()
      ..sort();
    final vmIds = filteredViewModels.map((vm) => vm.id).toList();

    if (filteredViewModels.isEmpty && bindingIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.device_hub, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Graph Data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try refreshing or ensure your app has bindings.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const canvasMinWidth = 1200.0;
        const padding = 24.0;
        const bindingSize = Size(220, 44);
        const vmSize = Size(280, 64);
        const gap = 16.0;

        final maxNodes = max(bindingIds.length, vmIds.length);
        final canvasHeight = max(
          constraints.maxHeight,
          padding * 2 + maxNodes * (vmSize.height + gap),
        );
        final canvasWidth = max(constraints.maxWidth, canvasMinWidth);

        final bindingRects = _layoutNodes(
          ids: bindingIds,
          nodeSize: bindingSize,
          x: padding,
          canvasHeight: canvasHeight,
          padding: padding,
          gap: gap,
        );
        final vmRects = _layoutNodes(
          ids: vmIds,
          nodeSize: vmSize,
          x: canvasWidth - padding - vmSize.width,
          canvasHeight: canvasHeight,
          padding: padding,
          gap: gap,
        );

        return InteractiveViewer(
          constrained: false,
          minScale: 0.6,
          maxScale: 2.5,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(canvasWidth, canvasHeight),
                  painter: _GraphPainter(
                    edges: edges,
                    bindingRects: bindingRects,
                    vmRects: vmRects,
                    vmMap: vmMap,
                    theme: Theme.of(context),
                  ),
                ),
                ...bindingIds.map((id) {
                  final rect = bindingRects[id]!;
                  return Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: _BindingNode(
                      bindingId: id,
                      viewModels: _bindingViewModels(id, edges, vmMap),
                    ),
                  );
                }),
                ...vmIds.map((id) {
                  final rect = vmRects[id]!;
                  final vm = vmMap[id]!;
                  return Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: _ViewModelNode(viewModel: vm),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  List<ViewModelInfo> _filterViewModels() {
    switch (filter) {
      case 'active':
        return viewModels.where((vm) => vm.status == 'active').toList();
      case 'disposed':
        return viewModels.where((vm) => vm.status == 'disposed').toList();
      default:
        return List<ViewModelInfo>.from(viewModels);
    }
  }

  Map<String, Rect> _layoutNodes({
    required List<String> ids,
    required Size nodeSize,
    required double x,
    required double canvasHeight,
    required double padding,
    required double gap,
  }) {
    final rects = <String, Rect>{};
    if (ids.isEmpty) return rects;

    final totalHeight =
        ids.length * nodeSize.height + (ids.length - 1) * gap;
    final startY = max(padding, (canvasHeight - totalHeight) / 2);

    for (var i = 0; i < ids.length; i++) {
      final y = startY + i * (nodeSize.height + gap);
      rects[ids[i]] = Rect.fromLTWH(x, y, nodeSize.width, nodeSize.height);
    }
    return rects;
  }

  List<ViewModelInfo> _bindingViewModels(
    String bindingId,
    List<DependencyEdge> edges,
    Map<String, ViewModelInfo> vmMap,
  ) {
    final ids = edges
        .where((edge) => edge.from == bindingId)
        .map((edge) => edge.to)
        .toSet();
    return ids
        .map((id) => vmMap[id])
        .whereType<ViewModelInfo>()
        .toList();
  }
}

class _BindingNode extends StatelessWidget {
  final String bindingId;
  final List<ViewModelInfo> viewModels;

  const _BindingNode({
    required this.bindingId,
    required this.viewModels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = viewModels.length;

    return InkWell(
      onTap: () => _showBindingDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withAlpha(160),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.secondary.withAlpha(130),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withAlpha(12),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.secondary.withAlpha(40),
              child: Icon(
                Icons.link,
                size: 16,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bindingId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$count ViewModels',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBindingDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return BindingDetailsDialog(
          bindingId: bindingId,
          viewModels: viewModels,
        );
      },
    );
  }
}

class _ViewModelNode extends StatelessWidget {
  final ViewModelInfo viewModel;

  const _ViewModelNode({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final isActive = viewModel.status == 'active';
    final statusColor = isActive ? Colors.green : Colors.orange;
    final keyValue = viewModel.properties['key']?.toString();
    final tagValue = viewModel.properties['tag']?.toString();
    final subtitle = [
      if (keyValue != null && keyValue.isNotEmpty) 'key: $keyValue',
      if (tagValue != null && tagValue.isNotEmpty) 'tag: $tagValue',
    ].join(' • ');

    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showViewModelDetails(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withAlpha(140)),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              color: Colors.black.withAlpha(14),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: statusColor.withAlpha(38),
              child: Icon(
                isActive ? Icons.play_circle_fill : Icons.delete_outline,
                color: statusColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    viewModel.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    viewModel.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withAlpha(170),
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showViewModelDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return ViewModelDetailsDialog(viewModel: viewModel);
      },
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<DependencyEdge> edges;
  final Map<String, Rect> bindingRects;
  final Map<String, Rect> vmRects;
  final Map<String, ViewModelInfo> vmMap;
  final ThemeData theme;

  _GraphPainter({
    required this.edges,
    required this.bindingRects,
    required this.vmRects,
    required this.vmMap,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = theme.dividerColor.withAlpha(60);
    const gridSize = 64.0;
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = theme.colorScheme.primary.withAlpha(120);

    for (final edge in edges) {
      final fromRect = bindingRects[edge.from];
      final toRect = vmRects[edge.to];
      if (fromRect == null || toRect == null) continue;

      final start = Offset(fromRect.right, fromRect.center.dy);
      final end = Offset(toRect.left, toRect.center.dy);
      final midX = (start.dx + end.dx) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);

      final vm = vmMap[edge.to];
      final isActive = vm?.status == 'active';
      final color = isActive ? Colors.green : Colors.orange;
      canvas.drawPath(path, basePaint..color = color.withAlpha(140));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.edges != edges ||
        oldDelegate.bindingRects != bindingRects ||
        oldDelegate.vmRects != vmRects ||
        oldDelegate.vmMap != vmMap;
  }
}

class ViewModelDetailsDialog extends StatelessWidget {
  final ViewModelInfo viewModel;

  const ViewModelDetailsDialog({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final isActive = viewModel.status == 'active';
    final statusColor = isActive ? Colors.green : Colors.orange;
    final bindings = _getBindings(viewModel);

    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withAlpha(51),
                  child: Icon(
                    isActive ? Icons.play_circle_filled : Icons.delete_outline,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.type,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'ID: ${viewModel.id}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withAlpha(76)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: statusColor),
                      const SizedBox(width: 8),
                      Text(
                        'Status: ${viewModel.status.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${_formatFullDateTime(viewModel.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (viewModel.status == 'disposed' &&
                      viewModel.properties['disposeTime'] != null)
                    Text(
                      'Disposed: ${_formatFullDateTime(DateTime.parse(viewModel.properties['disposeTime'] as String))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Properties'),
                        Tab(text: 'Bindings'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildPropertiesTab(context),
                          _buildBindingsTab(context, bindings),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesTab(BuildContext context) {
    final properties = viewModel.properties.entries
        .where((entry) => entry.key != 'bindings')
        .toList();

    if (properties.isEmpty) {
      return const Center(
        child: Text('No properties available'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final entry = properties[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(76),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    entry.value.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBindingsTab(BuildContext context, List<String> bindings) {
    if (bindings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No bindings'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bindings.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.withAlpha(51),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            title: SelectableText(
              bindings[index],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        );
      },
    );
  }

  List<String> _getBindings(ViewModelInfo viewModel) {
    final bindings = viewModel.properties['bindings'] as List<dynamic>? ?? [];
    return bindings.map((binding) => binding.toString()).toList();
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}

class BindingDetailsDialog extends StatelessWidget {
  final String bindingId;
  final List<ViewModelInfo> viewModels;

  const BindingDetailsDialog({
    super.key,
    required this.bindingId,
    required this.viewModels,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 520,
        height: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withAlpha(38),
                  child: Icon(
                    Icons.link,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bindingId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Connected ViewModels (${viewModels.length})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: viewModels.isEmpty
                  ? const Center(child: Text('No connected ViewModels'))
                  : ListView.builder(
                      itemCount: viewModels.length,
                      itemBuilder: (context, index) {
                        final vm = viewModels[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(vm.type),
                            subtitle: Text(
                              vm.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              vm.status,
                              style: TextStyle(
                                color: vm.status == 'active'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
