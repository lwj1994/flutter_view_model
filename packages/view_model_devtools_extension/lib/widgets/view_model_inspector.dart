import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../services/view_model_service.dart';
import '../widgets/filter_controls.dart';
import '../widgets/stats_panel.dart';
import '../widgets/view_model_list.dart';

class ViewModelInspector extends StatefulWidget {
  const ViewModelInspector({super.key});

  @override
  State<ViewModelInspector> createState() => _ViewModelInspectorState();
}

class _ViewModelInspectorState extends State<ViewModelInspector> {
  List<ViewModelInfo> _viewModels = [];
  DependencyStats _stats = DependencyStats.empty();
  DependencyGraphResult _graph =
      DependencyGraphResult(nodes: [], edges: []);
  Timer? _refreshTimer;
  String _filter = 'all';
  bool _realTimeUpdate = true;
  bool _isLoading = false;
  String? _connectionError;

  late final ViewModelService _viewModelService;

  @override
  void initState() {
    super.initState();
    _viewModelService = ViewModelService();
    _setupConnectionListener();
    _loadViewModelData();
    if (_realTimeUpdate) {
      _startRealTimeUpdate();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupConnectionListener() {
    final serviceManager = globals[ServiceManager] as ServiceManager?;
    serviceManager?.connectedState.addListener(() {
      final connected = serviceManager.connectedState.value.connected;
      if (connected) {
        setState(() {
          _connectionError = null;
        });
        _loadViewModelData();
      }
    });
  }

  void _startRealTimeUpdate() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadViewModelData();
    });
  }

  void _stopRealTimeUpdate() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadViewModelData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _viewModelService.getViewModelData(),
        _viewModelService.getDependencyGraph(),
      ]);
      final result = results[0] as ViewModelDataResult;
      final graph = results[1] as DependencyGraphResult;
      setState(() {
        _viewModels = result.viewModels;
        _stats = result.stats;
        _graph = graph;
        _isLoading = false;
        _connectionError = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _viewModels = [];
        _stats = DependencyStats.empty();
        _graph = DependencyGraphResult(nodes: [], edges: []);
        _connectionError = e.toString();
      });
    }
  }

  void _toggleRealTimeUpdate() {
    setState(() {
      _realTimeUpdate = !_realTimeUpdate;
    });

    if (_realTimeUpdate) {
      _startRealTimeUpdate();
    } else {
      _stopRealTimeUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _connectionError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadViewModelData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionTitle(title: 'Controls'),
                const SizedBox(height: 8),
                FilterControls(
                  filter: _filter,
                  realTimeUpdate: _realTimeUpdate,
                  onFilterChanged: (filter) => setState(() => _filter = filter),
                  onRealTimeToggle: _toggleRealTimeUpdate,
                  onRefresh: _loadViewModelData,
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: 'Stats'),
                const SizedBox(height: 8),
                StatsPanel(stats: _stats),
                const SizedBox(height: 24),
                _SectionTitle(title: 'Canvas'),
                const SizedBox(height: 8),
                _InfoTile(
                  title: 'Bindings',
                  value: _graph.edges.map((e) => e.from).toSet().length,
                ),
                const SizedBox(height: 8),
                _InfoTile(
                  title: 'ViewModels',
                  value: _viewModels.length,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ViewModelGraph(
                      viewModels: _viewModels,
                      graph: _graph,
                      filter: _filter,
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final int value;

  const _InfoTile({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
