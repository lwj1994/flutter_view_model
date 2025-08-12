import 'package:flutter/material.dart';

import '../services/view_model_service.dart';

class ViewModelList extends StatelessWidget {
  final List<ViewModelInfo> viewModels;
  final String filter;

  const ViewModelList({
    super.key,
    required this.viewModels,
    required this.filter,
  });

  double _calculateCardWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const minCardWidth = 300.0;
    const maxCardWidth = 400.0;
    const padding = 16.0; // Total horizontal padding

    // Calculate how many cards can fit in one row
    final availableWidth = screenWidth - padding;
    final cardsPerRow = (availableWidth / minCardWidth).floor().clamp(1, 4);

    // Calculate actual card width
    final cardWidth = (availableWidth - (cardsPerRow - 1) * 8.0) / cardsPerRow;

    return cardWidth.clamp(minCardWidth, maxCardWidth);
  }

  List<ViewModelInfo> get filteredViewModels {
    List<ViewModelInfo> filtered;
    switch (filter) {
      case 'active':
        filtered = viewModels.where((vm) => vm.status == 'active').toList();
        break;
      case 'disposed':
        filtered = viewModels.where((vm) => vm.status == 'disposed').toList();
        break;
      default:
        filtered = viewModels;
    }

    // Sort by appropriate time based on status
    filtered.sort((a, b) {
      if (a.status == 'disposed' && b.status == 'disposed') {
        // For disposed ViewModels, sort by dispose time (newest first)
        final aDisposeTime = a.properties['disposeTime'] as String?;
        final bDisposeTime = b.properties['disposeTime'] as String?;
        if (aDisposeTime != null && bDisposeTime != null) {
          final aTime = DateTime.parse(aDisposeTime);
          final bTime = DateTime.parse(bDisposeTime);
          return bTime.compareTo(aTime);
        }
        // Fallback to creation time if dispose time is not available
        return b.createdAt.compareTo(a.createdAt);
      } else if (a.status == 'active' && b.status == 'active') {
        // For active ViewModels, sort by creation time (newest first)
        return b.createdAt.compareTo(a.createdAt);
      } else {
        // Mixed status: compare disposed time with creation time
        DateTime aTime, bTime;
        if (a.status == 'disposed') {
          final aDisposeTime = a.properties['disposeTime'] as String?;
          aTime =
              aDisposeTime != null ? DateTime.parse(aDisposeTime) : a.createdAt;
        } else {
          aTime = a.createdAt;
        }

        if (b.status == 'disposed') {
          final bDisposeTime = b.properties['disposeTime'] as String?;
          bTime =
              bDisposeTime != null ? DateTime.parse(bDisposeTime) : b.createdAt;
        } else {
          bTime = b.createdAt;
        }

        return bTime.compareTo(aTime);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredViewModels;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ViewModels Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter or make sure your app is using ViewModels.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: filtered.map((viewModel) {
            return SizedBox(
              width: _calculateCardWidth(context),
              child: ViewModelTile(viewModel: viewModel),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ViewModelTile extends StatelessWidget {
  final ViewModelInfo viewModel;

  const ViewModelTile({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final isActive = viewModel.status == 'active';
    final statusColor = isActive ? Colors.green : Colors.orange;

    return GestureDetector(
      onTap: () => _showViewModelDetails(context),
      child: Card(
        margin: const EdgeInsets.all(4.0),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.black45,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header section
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(
                      isActive
                          ? Icons.play_circle_filled
                          : Icons.delete_outline,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewModel.type,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${viewModel.id}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${viewModel.status} • ${_formatDateTime(viewModel.createdAt)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: statusColor,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Properties section (compact)
              if (viewModel.properties.isNotEmpty &&
                  viewModel.properties.entries
                      .where((e) => e.key != 'watchers')
                      .isNotEmpty) ...[
                Text(
                  'Properties (${viewModel.properties.entries.where((e) => e.key != 'watchers').length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: viewModel.properties.entries
                        .where((entry) => entry.key != 'watchers')
                        .take(3) // Limit to 3 properties for compact view
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              children: [
                                Text(
                                  '${entry.key}:',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    entry.value.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontFamily: 'monospace',
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Watchers section (compact)
              Row(
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Watchers: ${_getWatchersCount(viewModel)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getWatchers(ViewModelInfo viewModel) {
    final watchers = viewModel.properties['watchers'] as List<dynamic>? ?? [];
    return watchers.map((w) => w.toString()).toList();
  }

  int _getWatchersCount(ViewModelInfo viewModel) {
    return _getWatchers(viewModel).length;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  void _showViewModelDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ViewModelDetailsDialog(viewModel: viewModel);
      },
    );
  }
}

class ViewModelDetailsDialog extends StatelessWidget {
  final ViewModelInfo viewModel;

  const ViewModelDetailsDialog({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final isActive = viewModel.status == 'active';
    final statusColor = isActive ? Colors.green : Colors.orange;
    final watchers = _getWatchers(viewModel);

    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withOpacity(0.2),
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
            // Status and Time Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
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
            // Content
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Properties'),
                        Tab(text: 'Watchers'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Properties Tab
                          _buildPropertiesTab(context),
                          // Watchers Tab
                          _buildWatchersTab(context, watchers),
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
        .where((entry) => entry.key != 'watchers')
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
                        .withOpacity(0.3),
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

  Widget _buildWatchersTab(BuildContext context, List<String> watchers) {
    if (watchers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.visibility_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No watchers'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: watchers.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.withOpacity(0.2),
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
              watchers[index],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        );
      },
    );
  }

  List<String> _getWatchers(ViewModelInfo viewModel) {
    final watchers = viewModel.properties['watchers'] as List<dynamic>? ?? [];
    return watchers.map((w) => w.toString()).toList();
  }

  String _formatFullDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
