import 'dart:core';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'test_model.dart';

class TestLifeCycleModel implements InstanceLifeCycle {
  int onCreateCount = 0;
  int onDisposeCount = 0;
  int onAddBinderCount = 0;
  int onRemoveBinderCount = 0;
  String? lastVefId;

  @override
  void onCreate(InstanceArg arg) {
    onCreateCount++;
  }

  @override
  void onDispose(InstanceArg arg) {
    onDisposeCount++;
  }

  @override
  void onBindVef(InstanceArg arg, String vefId) {
    onAddBinderCount++;
    lastVefId = vefId;
  }

  @override
  void onUnbindVef(InstanceArg arg, String vefId) {
    onRemoveBinderCount++;
    lastVefId = vefId;
  }
}

class ErrorDisposeModel implements InstanceLifeCycle {
  @override
  void onBindVef(InstanceArg arg, String vefId) {}

  @override
  void onCreate(InstanceArg arg) {}

  @override
  void onDispose(InstanceArg arg) {
    throw Exception("Dispose error");
  }

  @override
  void onUnbindVef(InstanceArg arg, String vefId) {}
}

class UnusedModel {}

void main() {
  group('get_instance', () {
    setUp(() {
      ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));
    });
    test('key = null', () {
      final factory = InstanceFactory<TestModel>(
        builder: () => TestModel(),
      );
      final a = instanceManager.get<TestModel>(factory: factory);
      final b = instanceManager.get<TestModel>(factory: factory);
      final c = instanceManager.get<TestModel>(factory: factory);
      assert(a != b);
      assert(b != c);
    });

    test('share key', () {
      final factory = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(key: "share"));
      final a = instanceManager.get<TestModel>(factory: factory);
      final b = instanceManager.get<TestModel>(factory: factory);
      final c = instanceManager.get<TestModel>(factory: factory);
      assert(a == b);
      assert(b == c);
    });

    test('get different type', () {
      final factory = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(key: "share"));
      final factoryB = InstanceFactory<TestModelB>(
          builder: () => TestModelB(), arg: const InstanceArg(key: "share"));
      final a = instanceManager.get<TestModel>(factory: factory);
      final a1 = instanceManager.get<TestModel>(factory: factory);
      final b = instanceManager.get<TestModelB>(factory: factoryB);
      final b1 = instanceManager.get<TestModelB>(factory: factoryB);

      assert(a == a1);
      assert(b == b1);
    });

    test('recycle', () {
      final factory = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(key: "share"));
      final InstanceHandle<TestModel> a =
          instanceManager.getNotifier<TestModel>(factory: factory);

      a.unbindAll();

      final InstanceHandle<TestModel> a1 =
          instanceManager.getNotifier<TestModel>(factory: factory);
      assert(a != a1);
    });

    test('recreate', () {
      final factory = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(key: "share"));
      final a = instanceManager.get<TestModel>(factory: factory);
      final a1 = instanceManager.recreate<TestModel>(a);
      assert(a != a1);
    });

    test('recreate with new builder', () {
      final factory = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(key: "share"));
      final a = instanceManager.get<TestModel>(factory: factory);
      final newT = TestModel();
      final a1 = instanceManager.recreate<TestModel>(a, builder: () {
        return newT;
      });
      assert(a != a1);
      assert(newT == a1);
    });

    test('get exiting instance', () {
      final factory = InstanceFactory<TestModel>(
        builder: () => TestModel(),
      );
      final b = instanceManager.get<TestModel>(factory: factory);
      final c = instanceManager.get<TestModel>();
      // assert(a != b);
      assert(c == b);
    });

    test('get exiting instance by tag', () {
      final factory = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(tag: "tag"));
      final factory2 = InstanceFactory<TestModel>(
        builder: () => TestModel(),
      );
      final factory3 = InstanceFactory<TestModel>(
          builder: () => TestModel(), arg: const InstanceArg(tag: "tag3"));
      final a = instanceManager.get<TestModel>(factory: factory);
      final b = instanceManager.get<TestModel>(factory: factory2);
      final c = instanceManager.get<TestModel>(factory: factory3);
      assert(a != b);
      assert(a != c);

      final find = instanceManager.getNotifier<TestModel>(
        factory: InstanceFactory(
          arg: const InstanceArg(tag: "tag"),
        ),
      );
      assert(find.arg.tag == "tag");

      final find2 = instanceManager.getNotifier<TestModel>(
        factory: InstanceFactory(
          arg: const InstanceArg(tag: "tag3"),
        ),
      );
      assert(find2.arg.tag == "tag3");

      final find3 = instanceManager.getNotifier<TestModel>();
      assert(find3.arg.tag == "tag3");
    });

    test('get exiting instance with watchId', () async {
      final factory = InstanceFactory<TestModel>(
        builder: () => TestModel(),
      );
      final a = instanceManager.getNotifier<TestModel>(factory: factory);
      print(a.index);
      final b = instanceManager.getNotifier<TestModel>(factory: factory);
      print(b.index);
      assert(a.index < b.index);
      final c = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory.vef(
        vefId: "watchId_c",
      ));
      assert(c == b);
      b.unbindAll();
      await Future.delayed(const Duration(seconds: 1));
      assert(c.bindedVefIds.isEmpty);
    });

    test('find exiting', () async {
      final factory = InstanceFactory<TestModel>(
        builder: () => TestModel(),
      );
      final a = instanceManager.getNotifier<TestModel>(factory: factory);
      final b = instanceManager.getNotifier<TestModel>(factory: factory);
      final c = instanceManager.getNotifier<TestModel>(factory: factory);
      final d = instanceManager.getNotifier<TestModel>(factory: factory);

      final findNewlyCreated = instanceManager.getNotifier<TestModel>();

      assert(d == findNewlyCreated);
      assert(a != b);
      assert(a != c);
      assert(a != d);
    });

    test('error handling - dynamic type', () {
      expect(
        () => instanceManager.getNotifier<dynamic>(),
        throwsA(isA<ViewModelError>().having(
          (e) => e.message.toString(),
          'message',
          contains('T is dynamic'),
        )),
      );
    });

    test('error handling - no instance found', () {
      expect(
        () => instanceManager.getNotifier<UnusedModel>(),
        throwsA(isA<ViewModelError>().having(
          (e) => e.message.toString(),
          'message',
          contains('no UnusedModel instance found'),
        )),
      );
    });

    test('error handling - factory null builder and cache null', () {
      expect(
        () => instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(arg: const InstanceArg(key: 'non_existent')),
        ),
        throwsA(isA<ViewModelError>().having(
          (e) => e.message.toString(),
          'message',
          contains('TestModel factory == null and cache is null'),
        )),
      );
    });

    test('maybeGet', () {
      final result = instanceManager.maybeGet<TestModel>(
        factory: InstanceFactory(arg: const InstanceArg(key: 'maybe_missing')),
      );
      expect(result, isNull);

      final factory = InstanceFactory<TestModel>(
        builder: () => TestModel(),
        arg: const InstanceArg(key: 'maybe_exists'),
      );
      final instance = instanceManager.maybeGet<TestModel>(factory: factory);
      expect(instance, isNotNull);
    });

    test('lifecycle callbacks', () {
      final factory = InstanceFactory<TestLifeCycleModel>(
        builder: () => TestLifeCycleModel(),
        arg: const InstanceArg(key: 'lifecycle'),
      );

      final handle =
          instanceManager.getNotifier<TestLifeCycleModel>(factory: factory);
      final model = handle.instance;

      expect(model.onCreateCount, 1);

      handle.bindVef('binder1');
      expect(model.onAddBinderCount, 1);
      expect(model.lastVefId, 'binder1');

      handle.unbindVef('binder1');
      expect(model.onRemoveBinderCount, 1);
      expect(model.lastVefId, 'binder1');

      // removing last binder triggers recycle
      expect(model.onDisposeCount, 1);
    });

    test('lifecycle dispose error', () {
      final factory = InstanceFactory<ErrorDisposeModel>(
        builder: () => ErrorDisposeModel(),
        arg: const InstanceArg(key: 'error_dispose'),
      );

      final handle =
          instanceManager.getNotifier<ErrorDisposeModel>(factory: factory);

      // Should not throw exception but log error
      handle.unbindAll();
      expect(handle.action, InstanceAction.dispose);
      expect(() => handle.instance, throwsA(isA<Error>()));
    });

    test('InstanceArg equality', () {
      const arg1 = InstanceArg(key: 'k', tag: 't', vefId: 'b');
      const arg2 = InstanceArg(key: 'k', tag: 't', vefId: 'b');
      const arg3 = InstanceArg(key: 'k2', tag: 't', vefId: 'b');

      expect(arg1, equals(arg2));
      expect(arg1.hashCode, equals(arg2.hashCode));
      expect(arg1, isNot(equals(arg3)));
      expect(arg1.toString(), contains('key: k'));

      final argMap = arg1.toMap();
      expect(argMap['key'], 'k');

      final argFromMap = InstanceArg.fromMap(argMap);
      expect(argFromMap, equals(arg1));
    });
  });

  group('InstanceFactory', () {
    test('copyWith works', () {
      final f1 = InstanceFactory<TestModel>(
        builder: () => TestModel(),
        arg: const InstanceArg(key: 'k1'),
      );
      final f2 = f1.copyWith(arg: const InstanceArg(key: 'k2'));
      expect(f2.arg.key, 'k2');
      expect(f2.builder, isNotNull);

      final f3 = f1.copyWith(
          factory: null); // Should keep original builder if null passed
      expect(f3.builder, isNotNull);
    });

    test('toString contains type', () {
      final f = InstanceFactory<TestModel>();
      expect(f.toString(), contains('TestModel'));
      expect(f.toString(), contains('InstanceFactory'));
    });

    test('watch factory creates correct arg', () {
      final f = InstanceFactory.vef(vefId: 'w1');
      expect(f.arg.vefId, 'w1');
      expect(f.builder, isNull);
    });
  });

  group('InstanceManager Extended', () {
    test('findNewlyInstance returns latest', () {
      // Create multiple instances of TestModel
      final factory1 = InstanceFactory<TestModel>(builder: () => TestModel());
      final h1 = instanceManager.getNotifier<TestModel>(factory: factory1);

      final factory2 = InstanceFactory<TestModel>(builder: () => TestModel());
      final h2 = instanceManager.getNotifier<TestModel>(factory: factory2);

      // Now getNotifier without factory should return h2 (latest)
      final hLatest = instanceManager.getNotifier<TestModel>();
      expect(hLatest, h2);
      expect(hLatest, isNot(h1));
    });

    test('findNewlyInstance filters by tag', () {
      final t1 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              builder: () => TestModel(), arg: const InstanceArg(tag: 'tagA')));
      final t2 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              builder: () => TestModel(), arg: const InstanceArg(tag: 'tagB')));
      final t3 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              builder: () => TestModel(),
              arg: const InstanceArg(tag: 'tagA')) // Newer tagA
          );

      // Find latest tagA
      final foundA = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              arg: const InstanceArg(tag: 'tagA')) // empty builder implies find
          );
      expect(foundA, t3);

      // Find latest tagB
      final foundB = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(arg: const InstanceArg(tag: 'tagB')));
      expect(foundB, t2);
    });

    test('index increment logic', () {
      final h1 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(builder: () => TestModel()));
      final h2 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(builder: () => TestModel()));
      final h3 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(builder: () => TestModel()));

      expect(h1.index, lessThan(h2.index));
      expect(h2.index, lessThan(h3.index));
      expect(h2.index, h1.index + 1);
      expect(h3.index, h2.index + 1);
    });

    test('getInstancesByTag returns sorted by index desc', () {
      const tag = 'sorted_tag';
      final h1 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              builder: () => TestModel(), arg: const InstanceArg(tag: tag)));
      final h2 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              builder: () => TestModel(), arg: const InstanceArg(tag: tag)));
      final h3 = instanceManager.getNotifier<TestModel>(
          factory: InstanceFactory(
              builder: () => TestModel(), arg: const InstanceArg(tag: tag)));

      final list = instanceManager.getNotifiersByTag<TestModel>(tag);
      expect(list.length, 3);
      expect(list[0], h3);
      expect(list[1], h2);
      expect(list[2], h1);
      expect(list[0].index > list[1].index, isTrue);
      expect(list[1].index > list[2].index, isTrue);
    });
  });
}
