import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';

class ViewModelService {
  Future<ViewModelDataResult> getViewModelData() async {
    final serviceManager = globals[ServiceManager] as ServiceManager?;

    if (serviceManager == null ||
        !serviceManager.connectedState.value.connected) {
      throw Exception(
        'DevTools VM Service connection not available. Please ensure your '
        'Flutter app is running in debug mode and connected to DevTools.',
      );
    }

    try {
      final response = await serviceManager
          .callServiceExtensionOnMainIsolate('ext.view_model.getViewModelData')
          .timeout(const Duration(seconds: 5));

      if (response.json != null) {
        final data = response.json!;
        final viewModelList = data['viewModels'] as List<dynamic>? ?? [];
        final bindingList = data['bindings'] as List<dynamic>? ?? [];

        final viewModels = viewModelList
            .map((vm) => ViewModelInfo.fromJson(vm as Map<String, dynamic>))
            .toList();

        final stats = DependencyStats.fromJson(
            data['stats'] as Map<String, dynamic>? ?? {});

        final bindings = bindingList
            .map(
              (binding) => BindingInfo.fromJson(
                binding as Map<String, dynamic>,
              ),
            )
            .toList();

        return ViewModelDataResult(
          viewModels: viewModels,
          bindings: bindings,
          stats: stats,
        );
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
        'DevTools VM Service connection not available. Please ensure your '
        'Flutter app is running in debug mode and connected to DevTools.',
      );
    }

    try {
      final response = await serviceManager
          .callServiceExtensionOnMainIsolate(
              'ext.view_model.getDependencyGraph')
          .timeout(const Duration(seconds: 5));

      if (response.json != null) {
        final data = response.json!;
        final viewModelList = data['viewModels'] as List<dynamic>? ?? [];
        final bindingList = data['bindings'] as List<dynamic>? ?? [];
        final relationshipList = data['relationships'] as List<dynamic>? ?? [];

        final viewModels = viewModelList
            .map(
              (viewModel) => DependencyViewModelNode.fromJson(
                viewModel as Map<String, dynamic>,
              ),
            )
            .toList();

        final bindings = bindingList
            .map(
              (binding) => BindingInfo.fromJson(
                binding as Map<String, dynamic>,
              ),
            )
            .toList();

        final relationships = relationshipList
            .map(
              (relationship) => DependencyRelationship.fromJson(
                relationship as Map<String, dynamic>,
              ),
            )
            .toList();

        return DependencyGraphResult(
          viewModels: viewModels,
          bindings: bindings,
          relationships: relationships,
        );
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
  final List<BindingInfo> bindings;
  final DependencyStats stats;

  ViewModelDataResult({
    required this.viewModels,
    this.bindings = const [],
    required this.stats,
  });
}

class DependencyGraphResult {
  final List<DependencyViewModelNode> viewModels;
  final List<BindingInfo> bindings;
  final List<DependencyRelationship> relationships;

  DependencyGraphResult({
    required this.viewModels,
    this.bindings = const [],
    required this.relationships,
  });
}

class BindingInfo {
  final String id;
  final String name;
  final String kind;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? disposeTime;
  final String? parentViewModelId;
  final String? parentViewModelType;

  bool get isDependency => kind == 'dependency';

  const BindingInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.isActive,
    required this.createdAt,
    this.disposeTime,
    this.parentViewModelId,
    this.parentViewModelType,
  });

  factory BindingInfo.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'] as String?;
    final disposeTime = json['disposeTime'] as String?;
    return BindingInfo(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      kind: json['kind'] as String? ?? 'unknown',
      isActive:
          json['isActive'] as bool? ?? !(json['isDisposed'] as bool? ?? false),
      createdAt: createdAt == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(createdAt),
      disposeTime: disposeTime == null ? null : DateTime.parse(disposeTime),
      parentViewModelId: json['parentViewModelId'] as String?,
      parentViewModelType: json['parentViewModelType'] as String?,
    );
  }
}

class DependencyViewModelNode {
  final String id;
  final String type;
  final String label;
  final bool isActive;
  final List<String> owners;
  final String? primaryOwner;
  final PrimaryOwnerHandoffInfo? primaryOwnerHandoff;

  DependencyViewModelNode({
    required this.id,
    required this.type,
    required this.label,
    required this.isActive,
    this.owners = const [],
    this.primaryOwner,
    this.primaryOwnerHandoff,
  });

  factory DependencyViewModelNode.fromJson(Map<String, dynamic> json) {
    final handoff = json['primaryOwnerHandoff'];
    return DependencyViewModelNode(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      isActive: json['isActive'] as bool? ?? true,
      owners: (json['owners'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      primaryOwner: json['primaryOwner'] as String?,
      primaryOwnerHandoff: handoff is Map<String, dynamic>
          ? PrimaryOwnerHandoffInfo.fromJson(handoff)
          : null,
    );
  }
}

class PrimaryOwnerHandoffInfo {
  final String from;
  final String to;
  final DateTime occurredAt;

  PrimaryOwnerHandoffInfo({
    required this.from,
    required this.to,
    required this.occurredAt,
  });

  factory PrimaryOwnerHandoffInfo.fromJson(Map<String, dynamic> json) {
    return PrimaryOwnerHandoffInfo(
      from: json['from'] as String,
      to: json['to'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}

class DependencyRelationship {
  final String source;
  final String target;
  final String kind;
  final bool isPrimaryOwner;

  bool get isPrimaryOwnerBinding =>
      kind == 'bindingOwnsViewModel' && isPrimaryOwner;
  bool get isBindingOwnership => kind == 'bindingOwnsViewModel';
  bool get isVirtualBindingOwnership =>
      kind == 'viewModelOwnsDependencyBinding';

  DependencyRelationship({
    required this.source,
    required this.target,
    required this.kind,
    this.isPrimaryOwner = false,
  });

  factory DependencyRelationship.fromJson(Map<String, dynamic> json) {
    return DependencyRelationship(
      source: json['source'] as String,
      target: json['target'] as String,
      kind: json['kind'] as String,
      isPrimaryOwner: json['isPrimaryOwner'] as bool? ?? false,
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
        'bindings': json['bindings'] as List<dynamic>? ?? [],
        if (json.containsKey('owners'))
          'owners': json['owners'] as List<dynamic>? ?? [],
        if (json.containsKey('primaryOwner'))
          'primaryOwner': json['primaryOwner'],
        if (json.containsKey('primaryOwnerHandoff'))
          'primaryOwnerHandoff': json['primaryOwnerHandoff'],
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
  final int totalBindings;
  final int activeBindings;
  final int disposedBindings;

  DependencyStats({
    required this.totalViewModels,
    required this.activeViewModels,
    required this.disposedViewModels,
    this.totalBindings = 0,
    this.activeBindings = 0,
    this.disposedBindings = 0,
  });

  factory DependencyStats.fromJson(Map<String, dynamic> json) {
    return DependencyStats(
      totalViewModels: json['totalInstances'] as int? ?? 0,
      activeViewModels: json['activeInstances'] as int? ?? 0,
      disposedViewModels: json['disposedInstances'] as int? ?? 0,
      totalBindings: json['totalBindings'] as int? ?? 0,
      activeBindings: json['activeBindings'] as int? ?? 0,
      disposedBindings: json['disposedBindings'] as int? ?? 0,
    );
  }

  factory DependencyStats.empty() {
    return DependencyStats(
      totalViewModels: 0,
      activeViewModels: 0,
      disposedViewModels: 0,
      totalBindings: 0,
      activeBindings: 0,
      disposedBindings: 0,
    );
  }
}
