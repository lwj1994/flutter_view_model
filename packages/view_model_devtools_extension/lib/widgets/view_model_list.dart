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
    final allVmMap = {for (final vm in viewModels) vm.id: vm};
    final bindings = _filterBindings()..sort(_compareBindings);
    final bindingMap = {for (final binding in bindings) binding.id: binding};
    final relationships = graph.relationships.where((relationship) {
      if (relationship.isBindingOwnership) {
        return bindingMap.containsKey(relationship.source) &&
            vmMap.containsKey(relationship.target);
      }
      if (relationship.isVirtualBindingOwnership) {
        return vmMap.containsKey(relationship.source) &&
            bindingMap.containsKey(relationship.target);
      }
      return false;
    }).toList();
    final vmIds = filteredViewModels.map((vm) => vm.id).toList();

    if (filteredViewModels.isEmpty && bindings.isEmpty) {
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
        const padding = 24.0;
        const bindingSize = Size(240, 58);
        const vmSize = Size(280, 64);
        final layout = _layoutGraph(
          bindingIds: bindings.map((binding) => binding.id).toList(),
          vmIds: vmIds,
          relationships: relationships,
          bindingSize: bindingSize,
          vmSize: vmSize,
          minimumSize: Size(constraints.maxWidth, constraints.maxHeight),
          padding: padding,
        );

        return InteractiveViewer(
          constrained: false,
          minScale: 0.6,
          maxScale: 2.5,
          child: SizedBox(
            width: layout.size.width,
            height: layout.size.height,
            child: Stack(
              children: [
                CustomPaint(
                  size: layout.size,
                  painter: _GraphPainter(
                    relationships: relationships,
                    bindingRects: layout.bindingRects,
                    vmRects: layout.vmRects,
                    vmMap: vmMap,
                    bindingMap: bindingMap,
                    theme: Theme.of(context),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: max(12, layout.size.width / 2 - 190),
                  child: const _GraphLegend(),
                ),
                ...bindings.map((binding) {
                  final rect = layout.bindingRects[binding.id]!;
                  return Positioned(
                    left: rect.left,
                    top: rect.top,
                    width: rect.width,
                    height: rect.height,
                    child: _BindingNode(
                      binding: binding,
                      viewModels: _bindingViewModels(
                        binding.id,
                        relationships,
                        vmMap,
                      ),
                      parentViewModel: allVmMap[binding.parentViewModelId],
                      primaryOwnerCount: relationships
                          .where(
                            (relationship) =>
                                relationship.source == binding.id &&
                                relationship.isPrimaryOwnerBinding,
                          )
                          .length,
                    ),
                  );
                }),
                ...vmIds.map((id) {
                  final rect = layout.vmRects[id]!;
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

  List<BindingInfo> _filterBindings() {
    switch (filter) {
      case 'active':
        return graph.bindings.where((binding) => binding.isActive).toList();
      case 'disposed':
        return graph.bindings.where((binding) => !binding.isActive).toList();
      default:
        return List<BindingInfo>.from(graph.bindings);
    }
  }

  int _compareBindings(BindingInfo left, BindingInfo right) {
    final kind = left.kind.compareTo(right.kind);
    if (kind != 0) return kind;
    return left.id.compareTo(right.id);
  }

  _GraphLayout _layoutGraph({
    required List<String> bindingIds,
    required List<String> vmIds,
    required List<DependencyRelationship> relationships,
    required Size bindingSize,
    required Size vmSize,
    required Size minimumSize,
    required double padding,
  }) {
    const horizontalGap = 112.0;
    const verticalSlot = 84.0;
    final nodeIds = <String>{...bindingIds, ...vmIds};
    final depths = {for (final id in nodeIds) id: 0};

    // The owner graph is acyclic. Longest-path depth naturally lays out
    // root binding → parent VM → virtual binding → child VM in order while
    // still supporting direct/shared owner edges that skip a column.
    for (var pass = 0; pass < nodeIds.length; pass++) {
      var changed = false;
      for (final relationship in relationships) {
        final fromDepth = depths[relationship.source];
        final toDepth = depths[relationship.target];
        if (fromDepth == null || toDepth == null) continue;
        final candidate = min(nodeIds.length - 1, fromDepth + 1);
        if (candidate <= toDepth) continue;
        depths[relationship.target] = candidate;
        changed = true;
      }
      if (!changed) break;
    }

    final columns = <int, List<String>>{};
    for (final id in nodeIds) {
      columns.putIfAbsent(depths[id]!, () => []).add(id);
    }
    for (final column in columns.values) {
      column.sort();
    }

    final maxDepth = depths.values.fold<int>(0, max);
    final maxColumnCount = columns.values.fold<int>(0, (value, column) {
      return max(value, column.length);
    });
    final columnWidth = max(bindingSize.width, vmSize.width);
    final intrinsicWidth =
        padding * 2 + (maxDepth + 1) * columnWidth + maxDepth * horizontalGap;
    final intrinsicHeight = padding * 2 + maxColumnCount * verticalSlot;
    final size = Size(
      max(1100, max(minimumSize.width, intrinsicWidth)),
      max(minimumSize.height, intrinsicHeight),
    );
    final bindingRects = <String, Rect>{};
    final vmRects = <String, Rect>{};

    for (var depth = 0; depth <= maxDepth; depth++) {
      final column = columns[depth] ?? const <String>[];
      final totalHeight = column.length * verticalSlot;
      final startY = max(padding + 42, (size.height - totalHeight) / 2);
      final slotX = padding + depth * (columnWidth + horizontalGap);
      for (var index = 0; index < column.length; index++) {
        final id = column[index];
        final isBinding = bindingIds.contains(id);
        final nodeSize = isBinding ? bindingSize : vmSize;
        final x = slotX + (columnWidth - nodeSize.width) / 2;
        final y = startY + index * verticalSlot;
        final rect = Rect.fromLTWH(x, y, nodeSize.width, nodeSize.height);
        if (isBinding) {
          bindingRects[id] = rect;
        } else {
          vmRects[id] = rect;
        }
      }
    }

    return _GraphLayout(
      size: size,
      bindingRects: bindingRects,
      vmRects: vmRects,
    );
  }

  List<ViewModelInfo> _bindingViewModels(
    String bindingId,
    List<DependencyRelationship> relationships,
    Map<String, ViewModelInfo> vmMap,
  ) {
    final ids = relationships
        .where(
          (relationship) =>
              relationship.isBindingOwnership &&
              relationship.source == bindingId,
        )
        .map((relationship) => relationship.target)
        .toSet();
    return ids.map((id) => vmMap[id]).whereType<ViewModelInfo>().toList();
  }
}

class _GraphLayout {
  final Size size;
  final Map<String, Rect> bindingRects;
  final Map<String, Rect> vmRects;

  const _GraphLayout({
    required this.size,
    required this.bindingRects,
    required this.vmRects,
  });
}

class _BindingNode extends StatelessWidget {
  final BindingInfo binding;
  final List<ViewModelInfo> viewModels;
  final ViewModelInfo? parentViewModel;
  final int primaryOwnerCount;

  const _BindingNode({
    required this.binding,
    required this.viewModels,
    required this.parentViewModel,
    required this.primaryOwnerCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = viewModels.length;
    final color = binding.isDependency
        ? theme.colorScheme.tertiary
        : theme.colorScheme.secondary;

    return InkWell(
      onTap: () => _showBindingDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(binding.isActive ? 28 : 14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withAlpha(binding.isActive ? 150 : 80),
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
              backgroundColor: color.withAlpha(40),
              child: Icon(
                binding.isDependency ? Icons.account_tree : Icons.link,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    binding.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  Text(
                    binding.isDependency
                        ? 'Virtual • $count ViewModels'
                        : primaryOwnerCount == 0
                            ? '$count ViewModels'
                            : '$count ViewModels • $primaryOwnerCount primary',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      height: 1,
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
          binding: binding,
          viewModels: viewModels,
          parentViewModel: parentViewModel,
        );
      },
    );
  }
}

class _GraphLegend extends StatelessWidget {
  const _GraphLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendLine(
              color: theme.colorScheme.primary,
              thickness: 3.2,
            ),
            const SizedBox(width: 6),
            const Text('Primary owner'),
            const SizedBox(width: 14),
            _LegendLine(
              color: theme.colorScheme.outline,
              thickness: 1.4,
            ),
            const SizedBox(width: 6),
            const Text('Other owner'),
            const SizedBox(width: 14),
            _LegendLine(
              color: theme.colorScheme.tertiary,
              thickness: 2,
              dashed: true,
            ),
            const SizedBox(width: 6),
            const Text('Virtual binding'),
          ],
        ),
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final double thickness;
  final bool dashed;

  const _LegendLine({
    required this.color,
    required this.thickness,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 8,
      child: Center(
        child: dashed
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => Container(width: 4, height: thickness, color: color),
                ),
              )
            : Container(
                height: thickness,
                color: color,
              ),
      ),
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
        padding: const EdgeInsets.all(8),
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                  Text(
                    viewModel.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                      fontSize: 10.5,
                      height: 1,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(170),
                        fontSize: 10.5,
                        height: 1,
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
  final List<DependencyRelationship> relationships;
  final Map<String, Rect> bindingRects;
  final Map<String, Rect> vmRects;
  final Map<String, ViewModelInfo> vmMap;
  final Map<String, BindingInfo> bindingMap;
  final ThemeData theme;

  _GraphPainter({
    required this.relationships,
    required this.bindingRects,
    required this.vmRects,
    required this.vmMap,
    required this.bindingMap,
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

    for (final relationship in relationships) {
      final isVirtual = relationship.isVirtualBindingOwnership;
      final fromRect = isVirtual
          ? vmRects[relationship.source]
          : bindingRects[relationship.source];
      final toRect = isVirtual
          ? bindingRects[relationship.target]
          : vmRects[relationship.target];
      if (fromRect == null || toRect == null) continue;

      final travelsRight = fromRect.center.dx <= toRect.center.dx;
      final start = Offset(
        travelsRight ? fromRect.right : fromRect.left,
        fromRect.center.dy,
      );
      final end = Offset(
        travelsRight ? toRect.left : toRect.right,
        toRect.center.dy,
      );
      final midX = (start.dx + end.dx) / 2;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);

      final vm = vmMap[relationship.target];
      final isActive = vm?.status == 'active';
      final bindingId = isVirtual ? relationship.target : relationship.source;
      final bindingIsActive = bindingMap[bindingId]?.isActive ?? true;
      final isPrimaryOwner = relationship.isPrimaryOwnerBinding;
      final color = isVirtual
          ? theme.colorScheme.tertiary
          : isPrimaryOwner
              ? theme.colorScheme.primary
              : isActive
                  ? Colors.green
                  : Colors.orange;
      final edgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isVirtual ? 2 : (isPrimaryOwner ? 3.2 : 1.4)
        ..strokeCap = StrokeCap.round
        ..color = color.withAlpha(
          !bindingIsActive
              ? 80
              : isVirtual || isPrimaryOwner
                  ? 220
                  : 120,
        );
      if (isVirtual) {
        _drawDashedPath(canvas, path, edgePaint);
      } else {
        canvas.drawPath(path, edgePaint);
      }

      if (isPrimaryOwner || isVirtual) {
        canvas.drawCircle(
          end,
          isVirtual ? 3.5 : 4,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color,
        );
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.relationships != relationships ||
        oldDelegate.bindingRects != bindingRects ||
        oldDelegate.vmRects != vmRects ||
        oldDelegate.vmMap != vmMap ||
        oldDelegate.bindingMap != bindingMap;
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
                      'Disposed: ${_formatFullDateTime(
                        DateTime.parse(
                          viewModel.properties['disposeTime'] as String,
                        ),
                      )}',
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
  final BindingInfo binding;
  final List<ViewModelInfo> viewModels;
  final ViewModelInfo? parentViewModel;

  const BindingDetailsDialog({
    super.key,
    required this.binding,
    required this.viewModels,
    required this.parentViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 560,
        height: 500,
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
                    binding.isDependency ? Icons.account_tree : Icons.link,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        binding.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      SelectableText(
                        binding.id,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    binding.isDependency ? Icons.account_tree : Icons.link,
                    size: 16,
                  ),
                  label: Text(
                    binding.isDependency ? 'Virtual binding' : 'Root binding',
                  ),
                ),
                Chip(
                  avatar: Icon(
                    binding.isActive
                        ? Icons.play_circle_fill
                        : Icons.delete_outline,
                    size: 16,
                    color: binding.isActive ? Colors.green : Colors.orange,
                  ),
                  label: Text(binding.isActive ? 'Active' : 'Disposed'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${_formatDateTime(binding.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (binding.disposeTime != null)
              Text(
                'Disposed: ${_formatDateTime(binding.disposeTime!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (binding.isDependency) ...[
              const SizedBox(height: 12),
              Text(
                'Owned by ViewModel generation',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                parentViewModel == null
                    ? '${binding.parentViewModelType ?? 'Unknown'}\n'
                        '${binding.parentViewModelId ?? 'Pending creation'}'
                    : '${parentViewModel!.type}\n${parentViewModel!.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ],
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

  String _formatDateTime(DateTime dateTime) {
    if (dateTime.millisecondsSinceEpoch == 0) return 'Unknown';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
