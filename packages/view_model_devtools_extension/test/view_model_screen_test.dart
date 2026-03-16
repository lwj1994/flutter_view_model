// ignore_for_file: subtype_of_sealed_class

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model_devtools_extension/services/view_model_service.dart';
import 'package:view_model_devtools_extension/widgets/view_model_inspector.dart';
import 'package:vm_service/vm_service.dart';

class TrackingConnectedState extends ValueNotifier<ConnectedState> {
  TrackingConnectedState(super.value);

  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }
}

class FakeServiceManager extends ServiceManager<VmService> {
  FakeServiceManager({
    required bool connected,
    required this.handlers,
  }) : _connectedState = TrackingConnectedState(
          ConnectedState(connected),
        );

  final TrackingConnectedState _connectedState;
  final Map<String, Response Function()> handlers;
  final List<String> invokedMethods = <String>[];

  @override
  ValueListenable<ConnectedState> get connectedState => _connectedState;

  bool get hasConnectionListeners => _connectedState.listenerCount > 0;

  void setConnected(bool connected) {
    _connectedState.value = ConnectedState(connected);
  }

  @override
  Future<Response> callServiceExtensionOnMainIsolate(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    invokedMethods.add(method);
    final handler = handlers[method];
    if (handler == null) {
      throw Exception('Unexpected service extension: $method');
    }
    return handler();
  }
}

Response _response(Map<String, dynamic> json) => Response()..json = json;

Map<String, dynamic> _viewModelDataJson() {
  return <String, dynamic>{
    'viewModels': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'vm-1',
        'type': 'CounterViewModel',
        'key': 'counter',
        'tag': 'main',
        'bindings': <String>['binding-1', 'binding-2'],
        'isActive': true,
        'createdAt': '2026-03-16T00:00:00.000Z',
      },
      <String, dynamic>{
        'id': 'vm-2',
        'type': 'TodoViewModel',
        'bindings': const <String>[],
        'isDisposed': true,
        'createdAt': '2026-03-16T01:00:00.000Z',
        'disposeTime': '2026-03-16T02:00:00.000Z',
      },
      <String, dynamic>{
        'id': 'vm-3',
        'type': 'ProfileViewModel',
        'bindings': const <String>[],
        'createdAt': '2026-03-16T03:00:00.000Z',
      },
    ],
    'stats': <String, dynamic>{
      'totalInstances': 3,
      'activeInstances': 1,
      'disposedInstances': 1,
    },
  };
}

Map<String, dynamic> _dependencyGraphJson() {
  return <String, dynamic>{
    'nodes': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'vm-1',
        'type': 'view_model',
        'label': 'CounterViewModel',
        'isActive': true,
      },
      <String, dynamic>{
        'id': 'vm-2',
        'type': 'view_model',
        'label': 'TodoViewModel',
        'isActive': false,
      },
    ],
    'edges': <Map<String, dynamic>>[
      <String, dynamic>{
        'from': 'binding-1',
        'to': 'vm-1',
        'type': 'binding',
      },
      <String, dynamic>{
        'from': 'binding-1',
        'to': 'vm-2',
        'type': 'binding',
      },
    ],
  };
}

void main() {
  late FakeServiceManager serviceManager;

  setUp(() {
    serviceManager = FakeServiceManager(
      connected: true,
      handlers: <String, Response Function()>{
        'ext.view_model.getViewModelData': () =>
            _response(_viewModelDataJson()),
        'ext.view_model.getDependencyGraph': () =>
            _response(_dependencyGraphJson()),
      },
    );
    globals[ServiceManager] = serviceManager;
  });

  tearDown(() {
    removeGlobal(ServiceManager);
  });

  group('ViewModelService', () {
    test('parses view model data from the extension response', () async {
      final result = await ViewModelService().getViewModelData();

      expect(result.viewModels, hasLength(3));
      expect(result.viewModels[0].type, 'CounterViewModel');
      expect(result.viewModels[0].status, 'active');
      expect(
        result.viewModels[0].properties['bindings'],
        ['binding-1', 'binding-2'],
      );
      expect(result.viewModels[1].status, 'disposed');
      expect(result.viewModels[1].lastUpdated, DateTime.utc(2026, 3, 16, 2));
      expect(result.viewModels[2].status, 'inactive');
      expect(result.stats.totalViewModels, 3);
      expect(result.stats.activeViewModels, 1);
      expect(result.stats.disposedViewModels, 1);
      expect(
        serviceManager.invokedMethods,
        ['ext.view_model.getViewModelData'],
      );
    });

    test('parses dependency graph data from the extension response', () async {
      final result = await ViewModelService().getDependencyGraph();

      expect(result.nodes, hasLength(2));
      expect(result.nodes.first.label, 'CounterViewModel');
      expect(result.edges, hasLength(2));
      expect(result.edges.first.from, 'binding-1');
      expect(result.edges.first.to, 'vm-1');
      expect(
        serviceManager.invokedMethods,
        ['ext.view_model.getDependencyGraph'],
      );
    });
  });

  testWidgets(
    'ViewModelInspector refreshes on reconnect and removes listeners '
    'on dispose',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      serviceManager.setConnected(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1400,
              height: 900,
              child: ViewModelInspector(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Connection Error'), findsOneWidget);
      expect(serviceManager.hasConnectionListeners, isTrue);

      serviceManager.setConnected(true);
      await tester.pump();
      await tester.pump();

      expect(find.text('Connection Error'), findsNothing);
      expect(find.text('CounterViewModel'), findsOneWidget);
      expect(find.text('binding-1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(serviceManager.hasConnectionListeners, isFalse);

      serviceManager.setConnected(false);
      serviceManager.setConnected(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
