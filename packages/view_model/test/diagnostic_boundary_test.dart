import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:view_model/src/devtool/service.dart';
import 'package:view_model/src/view_model/util.dart';
import 'package:view_model/view_model.dart';

class _DiagnosticVm with ViewModel {}

class _DiagnosticOwner extends ViewModelBinding {
  _DiagnosticOwner(this.spec);
  final ViewModelSpec<_DiagnosticVm> spec;
  _DiagnosticVm get vm => read(spec);
}

class _Key {
  bool fail = false;
  @override
  String toString() {
    if (fail) throw StateError('key formatting failed');
    return 'diagnostic-key';
  }
}

void main() {
  setUp(ViewModel.reset);
  tearDown(ViewModel.reset);

  test('DevTools registers idempotently and serves the live ownership graph',
      () async {
    final handlers = <String, developer.ServiceExtensionHandler>{};
    final service = DevToolsService(registerExtension: (name, handler) {
      expect(handlers.containsKey(name), isFalse);
      handlers[name] = handler;
    });
    addTearDown(service.dispose);
    service.initialize();
    service.initialize();
    expect(handlers.keys, [
      'ext.view_model.getViewModelData',
      'ext.view_model.getDependencyGraph',
    ]);
    final owner = _DiagnosticOwner(ViewModelSpec(
      builder: _DiagnosticVm.new,
      key: 'diagnostics',
    ));
    addTearDown(owner.dispose);
    owner.vm;
    for (final entry in handlers.entries) {
      final response = await entry.value(entry.key, {});
      expect(response.isError(), isFalse);
      final data = jsonDecode(response.result!) as Map<String, dynamic>;
      final vm = (data['viewModels'] as List).single as Map<String, dynamic>;
      expect(vm['owners'], [owner.id]);
      expect(vm['isActive'], isTrue);
    }
    owner.dispose();
    final response = await handlers['ext.view_model.getViewModelData']!(
      'ext.view_model.getViewModelData',
      {},
    );
    final data = jsonDecode(response.result!) as Map<String, dynamic>;
    expect((data['stats'] as Map)['activeInstances'], 0);
  });

  test('DevTools returns protocol errors when user metadata cannot serialize',
      () async {
    final handlers = <String, developer.ServiceExtensionHandler>{};
    final service = DevToolsService(registerExtension: (name, handler) {
      handlers[name] = handler;
    })
      ..initialize();
    final key = _Key();
    final owner = _DiagnosticOwner(ViewModelSpec(
      builder: _DiagnosticVm.new,
      key: key,
    ));
    addTearDown(service.dispose);
    addTearDown(owner.dispose);
    addTearDown(() => key.fail = false);
    owner.vm;
    key.fail = true;
    for (final entry in handlers.entries) {
      final response = await entry.value(entry.key, {});
      expect(response.errorCode,
          developer.ServiceExtensionResponse.extensionError);
      expect(response.errorDetail, contains('Unable to retrieve'));
      expect(response.result, isNull);
    }
  });

  test('stack locations skip framework frames and cache the application frame',
      () {
    var captures = 0;
    final locator = StackPathLocator(captureTrace: () {
      captures++;
      return Trace([
        Frame(Uri.parse('package:view_model/src/view_model/util.dart'), 1, 1,
            'StackPathLocator.getCurrentObjectPath'),
        Frame(Uri.parse('dart:async'), 2, 1, 'Zone.run'),
        Frame(Uri.parse('package:flutter/widgets.dart'), 3, 1, 'State.build'),
        Frame(Uri.parse('package:app/main.dart'), 42, 1, 'Page.initState'),
      ]);
    });
    expect(locator.ready, isFalse);
    expect(locator.getCurrentObjectPath(), 'app/main.dart:42 Page');
    expect(locator.getCurrentObjectPath(), 'app/main.dart:42 Page');
    expect(locator.ready, isTrue);
    expect(captures, 1);
  });

  test('missing stack locations cache an empty fallback', () {
    var captures = 0;
    final locator = StackPathLocator(captureTrace: () {
      captures++;
      return Trace([]);
    });
    expect(locator.getCurrentObjectPath(), isEmpty);
    expect(locator.getCurrentObjectPath(), isEmpty);
    expect(locator.ready, isFalse);
    expect(captures, 1);
  });

  test('stack capture failure logs once and preserves a usable empty fallback',
      () {
    final original = debugPrint;
    final messages = <String>[];
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = original);
    var captures = 0;
    final locator = StackPathLocator(captureTrace: () {
      captures++;
      throw StateError('stack unavailable');
    });
    expect(locator.getCurrentObjectPath(), isEmpty);
    expect(locator.getCurrentObjectPath(), isEmpty);
    expect(locator.ready, isFalse);
    expect(captures, 1);
    expect(messages.single, contains('stack unavailable'));
  });
}
