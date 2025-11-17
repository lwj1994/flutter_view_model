import 'dart:core';

import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model.dart';

import 'test_model.dart';

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

      a.recycle();

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
          factory: InstanceFactory.watch(
        watchId: "watchId_c",
      ));
      assert(c == b);
      b.recycle();
      await Future.delayed(const Duration(seconds: 1));
      assert(c.watchIds.isEmpty);
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
  });
}
