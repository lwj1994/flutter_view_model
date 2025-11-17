import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';

class ViewModelService {
  Future<ViewModelDataResult> getViewModelData() async {
    final serviceManager = globals[ServiceManager] as ServiceManager?;

    if (serviceManager == null ||
        !serviceManager.connectedState.value.connected) {
      throw Exception(
          'DevTools VM Service connection not available. Please ensure your Flutter app is running in debug mode and connected to DevTools.');
    }

    try {
      final response = await serviceManager
          .callServiceExtensionOnMainIsolate('ext.view_model.getViewModelData')
          .timeout(const Duration(seconds: 5));

      if (response.json != null) {
        final data = response.json!;
        final viewModelList = data['viewModels'] as List<dynamic>? ?? [];

        final viewModels = viewModelList
            .map((vm) => ViewModelInfo.fromJson(vm as Map<String, dynamic>))
            .toList();

        final stats = DependencyStats.fromJson(
            data['stats'] as Map<String, dynamic>? ?? {});

        return ViewModelDataResult(viewModels: viewModels, stats: stats);
      } else {
        throw Exception('No data received from Flutter app');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
            'Connection timeout. Please check if your app is responding.');
      }
      rethrow;
    }
  }

  Future<DependencyGraphResult> getDependencyGraph() async {
    final serviceManager = globals[ServiceManager] as ServiceManager?;

    if (serviceManager == null ||
        !serviceManager.connectedState.value.connected) {
      throw Exception(
          'DevTools VM Service connection not available. Please ensure your Flutter app is running in debug mode and connected to DevTools.');
    }

    try {
      final response = await serviceManager
          .callServiceExtensionOnMainIsolate(
              'ext.view_model.getDependencyGraph')
          .timeout(const Duration(seconds: 5));

      if (response.json != null) {
        final data = response.json!;
        final nodeList = data['nodes'] as List<dynamic>? ?? [];
        final edgeList = data['edges'] as List<dynamic>? ?? [];

        final nodes = nodeList
            .map(
                (node) => DependencyNode.fromJson(node as Map<String, dynamic>))
            .toList();

        final edges = edgeList
            .map(
                (edge) => DependencyEdge.fromJson(edge as Map<String, dynamic>))
            .toList();

        return DependencyGraphResult(nodes: nodes, edges: edges);
      } else {
        throw Exception('No dependency graph data received from Flutter app');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
            'Connection timeout. Please check if your app is responding.');
      }
      rethrow;
    }
  }
}

class ViewModelDataResult {
  final List<ViewModelInfo> viewModels;
  final DependencyStats stats;

  ViewModelDataResult({required this.viewModels, required this.stats});
}

class DependencyGraphResult {
  final List<DependencyNode> nodes;
  final List<DependencyEdge> edges;

  DependencyGraphResult({required this.nodes, required this.edges});
}

class DependencyNode {
  final String id;
  final String type;
  final String label;
  final bool isActive;

  DependencyNode({
    required this.id,
    required this.type,
    required this.label,
    required this.isActive,
  });

  factory DependencyNode.fromJson(Map<String, dynamic> json) {
    return DependencyNode(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class DependencyEdge {
  final String from;
  final String to;
  final String type;

  DependencyEdge({
    required this.from,
    required this.to,
    required this.type,
  });

  factory DependencyEdge.fromJson(Map<String, dynamic> json) {
    return DependencyEdge(
      from: json['from'] as String,
      to: json['to'] as String,
      type: json['type'] as String,
    );
  }
}

class ViewModelInfo {
  final String id;
  final String type;
  final String status;
  final Map<String, dynamic> properties;
  final DateTime createdAt;
  final DateTime? lastUpdated;

  ViewModelInfo({
    required this.id,
    required this.type,
    required this.status,
    required this.properties,
    required this.createdAt,
    this.lastUpdated,
  });

  factory ViewModelInfo.fromJson(Map<String, dynamic> json) {
    final isDisposed = json['isDisposed'] as bool? ?? false;
    final isActive = json['isActive'] as bool? ?? false;

    String status;
    if (isDisposed) {
      status = 'disposed';
    } else if (isActive) {
      status = 'active';
    } else {
      status = 'inactive';
    }

    return ViewModelInfo(
      id: json['id'] as String,
      type: json['type'] as String,
      status: status,
      properties: {
        'key': json['key'],
        'tag': json['tag'],
        'watchers': json['watchers'] as List<dynamic>? ?? [],
        if (isDisposed && json['disposeTime'] != null)
          'disposeTime': json['disposeTime'],
      },
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: json['disposeTime'] != null
          ? DateTime.parse(json['disposeTime'] as String)
          : DateTime.parse(json['createdAt'] as String),
    );
  }
}

class DependencyStats {
  final int totalViewModels;
  final int activeViewModels;
  final int disposedViewModels;

  DependencyStats({
    required this.totalViewModels,
    required this.activeViewModels,
    required this.disposedViewModels,
  });

  factory DependencyStats.fromJson(Map<String, dynamic> json) {
    return DependencyStats(
      totalViewModels: json['totalInstances'] as int? ?? 0,
      activeViewModels: json['activeInstances'] as int? ?? 0,
      disposedViewModels: json['disposedInstances'] as int? ?? 0,
    );
  }

  factory DependencyStats.empty() {
    return DependencyStats(
      totalViewModels: 0,
      activeViewModels: 0,
      disposedViewModels: 0,
    );
  }
}
