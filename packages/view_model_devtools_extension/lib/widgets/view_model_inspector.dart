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
      final result = await _viewModelService.getViewModelData();
      setState(() {
        _viewModels = result.viewModels;
        _stats = result.stats;
        _isLoading = false;
        _connectionError = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _viewModels = [];
        _stats = DependencyStats.empty();
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
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
      );
    }

    return Column(
      children: [
        FilterControls(
          filter: _filter,
          realTimeUpdate: _realTimeUpdate,
          onFilterChanged: (filter) => setState(() => _filter = filter),
          onRealTimeToggle: _toggleRealTimeUpdate,
          onRefresh: _loadViewModelData,
        ),
        StatsPanel(stats: _stats),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ViewModelList(
                  viewModels: _viewModels,
                  filter: _filter,
                ),
        ),
      ],
    );
  }
}
