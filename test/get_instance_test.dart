import 'dart:core';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';

import 'test_model.dart';

void main() {
  group('get_instance', () {
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
        builder: () => TestModel(),
        key: 'share',
      );
      final a = instanceManager.get<TestModel>(factory: factory);
      final b = instanceManager.get<TestModel>(factory: factory);
      final c = instanceManager.get<TestModel>(factory: factory);
      assert(a == b);
      assert(b == c);
    });

    test('get different type', () {
      final factory =
          InstanceFactory<TestModel>(builder: () => TestModel(), key: "share");
      final factoryB = InstanceFactory<TestModelB>(
          builder: () => TestModelB(), key: "share");
      final a = instanceManager.get<TestModel>(factory: factory);
      final a1 = instanceManager.get<TestModel>(factory: factory);
      final b = instanceManager.get<TestModelB>(factory: factoryB);
      final b1 = instanceManager.get<TestModelB>(factory: factoryB);

      assert(a == a1);
      assert(b == b1);
    });

    test('recycle', () {
      final factory =
          InstanceFactory<TestModel>(builder: () => TestModel(), key: "share");
      final InstanceNotifier<TestModel> a =
          instanceManager.getNotifier<TestModel>(factory: factory);

      a.recycle();

      final InstanceNotifier<TestModel> a1 =
          instanceManager.getNotifier<TestModel>(factory: factory);
      assert(a != a1);
    });

    test('recreate', () {
      final factory =
          InstanceFactory<TestModel>(builder: () => TestModel(), key: "share");
      final a = instanceManager.get<TestModel>(factory: factory);
      final a1 = instanceManager.recreate<TestModel>(a);
      assert(a != a1);
    });
  });
}
