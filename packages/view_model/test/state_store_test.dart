import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/state_store.dart';

class UnusedModel {}

void main() {
  group('StateStore Models', () {
    test('Reducer equality and hashCode', () {
      int func(int s) => s + 1;
      final r1 = Reducer<int>(builder: func);
      final r2 = Reducer<int>(builder: func);
      final r3 = Reducer<int>(builder: (s) => s + 2);

      expect(r1, r2);
      expect(r1.hashCode, r2.hashCode);
      expect(r1, isNot(r3));
    });

    test('DiffState equality, hashCode and toString', () {
      final d1 = DiffState<int>(1, 2);
      final d2 = DiffState<int>(1, 2);
      final d3 = DiffState<int>(2, 3);

      expect(d1, d2);
      expect(d1.hashCode, d2.hashCode);
      expect(d1, isNot(d3));

      expect(d1.toString(), contains('previousState: 1'));
      expect(d1.toString(), contains('currentState: 2'));
    });
  });

  group('Reducer', () {
    test('builder works', () async {
      final reducer = Reducer<int>(builder: (s) => s + 1);
      expect(await reducer.builder(1), 2);
    });
  });

  group('ViewModelStateStore', () {
    test('initial state', () {
      final store = ViewModelStateStore<int>(initialState: 10);
      expect(store.state, 10);
      expect(store.previousState, isNull);
      store.dispose();
    });

    test('setState updates state and notifies', () async {
      final store = ViewModelStateStore<int>(initialState: 0);
      final events = <DiffState<int>>[];
      final sub = store.stateStream.listen(events.add);

      store.setState(1);
      await Future.delayed(Duration.zero);

      expect(store.state, 1);
      expect(store.previousState, 0);
      expect(events.length, 1);
      expect(events.first.currentState, 1);
      expect(events.first.previousState, 0);

      await sub.cancel();
      store.dispose();
    });

    test('setState does not notify if same state (default equality)', () async {
      final store = ViewModelStateStore<int>(initialState: 0);
      bool notified = false;
      final sub = store.stateStream.listen((_) => notified = true);

      store.setState(0);
      await Future.delayed(Duration.zero);

      expect(notified, false);
      expect(store.previousState, isNull);

      await sub.cancel();
      store.dispose();
    });

    test('notifyListeners forces notification', () async {
      final store = ViewModelStateStore<int>(initialState: 0);
      bool notified = false;
      final sub = store.stateStream.listen((_) => notified = true);

      store.notifyListeners();
      await Future.delayed(Duration.zero);

      expect(notified, true);

      await sub.cancel();
      store.dispose();
    });

    test('uses custom equality from config', () async {
      final obj1 = UnusedModel();
      final obj2 = UnusedModel();
      final store = ViewModelStateStore<UnusedModel>(initialState: obj1);

      bool notified = false;
      store.stateStream.listen((_) => notified = true);

      // Same instance -> no update
      store.setState(obj1);
      await Future.delayed(Duration.zero);
      expect(notified, false);

      // Different instance -> update
      store.setState(obj2);
      await Future.delayed(Duration.zero);
      expect(notified, true);

      store.dispose();
    });
  });
}
