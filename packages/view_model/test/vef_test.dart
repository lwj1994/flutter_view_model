import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class SimpleVM with ViewModel {
  int count = 0;
}

class SimpleState {
  final int value;
  const SimpleState(this.value);
}

class SimpleStateVM extends StateViewModel<SimpleState> {
  SimpleStateVM({required SimpleState initial}) : super(state: initial);
}

class TestRef with Vef {}

class TestRefWithCounter with Vef {
  int updates = 0;
  @override
  void onUpdate() {
    super.onUpdate();
    updates++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vef core API (pure Dart)', () {
    test('maybeWatchCached returns null when not found', () {
      final ref = TestRef();
      final vm = ref.maybeWatchCached<SimpleVM>(key: 'missing');
      expect(vm, isNull);
      ref.dispose();
    });

    test('watchCached/maybeWatchCached by key returns same instance', () async {
      final ref = TestRef();
      final provider = ViewModelProvider<SimpleVM>(
        builder: () => SimpleVM(),
        key: 'kv-1',
      );
      final vm = ref.watch(provider);
      await Future.delayed(const Duration(milliseconds: 100));
      final byRead = ViewModel.readCached<SimpleVM>(key: 'kv-1');
      final byMaybe = ref.maybeWatchCached<SimpleVM>(key: 'kv-1');
      expect(identical(vm, byRead), isTrue);
      expect(identical(vm, byMaybe), isTrue);
      ref.dispose();
    });

    test('readCached by tag returns same instance', () async {
      final ref = TestRef();
      final provider = ViewModelProvider<SimpleVM>(
        builder: () => SimpleVM(),
        tag: 'tg-1',
      );
      final vm = ref.watch(provider);
      await Future.delayed(const Duration(milliseconds: 10));
      final byTag = ViewModel.readCached<SimpleVM>(tag: 'tg-1');
      expect(identical(vm, byTag), isTrue);
      ref.dispose();
    });
    test('maybeReadCached returns null when not found', () {
      final res = ViewModel.maybeReadCached<SimpleVM>(key: 'missing');
      expect(res, isNull);
    });

    test('readCached throws when missing', () {
      expect(
        () => ViewModel.readCached<SimpleVM>(key: 'missing'),
        throwsA(isA<Error>()),
      );
    });

    test('watch after ref.dispose throws error', () {
      final ref = TestRef();
      ref.dispose();
      expect(
        () => ref.watch<SimpleVM>(
          ViewModelProvider(builder: () => SimpleVM()),
        ),
        throwsA(isA<Error>()),
      );
    });

    test('listen/listenState/listenStateSelect callbacks fire', () async {
      final ref = TestRef();
      int listens = 0;
      final provider = ViewModelProvider(builder: () => SimpleVM());
      ref.listen<SimpleVM>(provider, onChanged: () => listens++);
      final vm = ref.watch<SimpleVM>(provider);
      vm.notifyListeners();
      expect(listens, 1);

      int stateListens = 0;
      final stateProvider = ViewModelProvider(
        builder: () => SimpleStateVM(initial: const SimpleState(0)),
      );
      final svm = ref.watch<SimpleStateVM>(stateProvider);
      svm.listenState(onChanged: (prev, cur) => stateListens++);
      svm.setState(const SimpleState(1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(stateListens, 1);

      int selectListens = 0;
      final svm2 = ref.watch<SimpleStateVM>(stateProvider);
      svm2.listenStateSelect<int>(
        selector: (s) => s.value,
        onChanged: (p, c) => selectListens++,
      );
      svm2.setState(const SimpleState(2));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(selectListens, 1);

      ref.dispose();
    });
  });

  group('Vef pause/resume missed updates', () {
    test('updates queued while paused, flushed on resume', () async {
      final ref = TestRefWithCounter();
      final provider = ViewModelProvider(builder: () => SimpleVM());
      final vm = ref.watch<SimpleVM>(provider);
      ref.updates = 0;

      final pauseProvider = AppPauseProvider();
      ref.addPauseProvider(pauseProvider);

      pauseProvider.pause();
      final baseline = ref.updates;
      vm.notifyListeners();
      await Future.delayed(const Duration(milliseconds: 20));

      pauseProvider.resume();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(ref.updates >= baseline + 1, isTrue);

      ref.dispose();
      pauseProvider.dispose();
    });
  });

  group('Vef recycle creates fresh instance', () {
    test('recycle then watch returns new instance', () {
      final ref = TestRef();
      final fac = ViewModelProvider<SimpleVM>(builder: () => SimpleVM());
      final a = ref.watch(fac);
      ref.recycle(a);
      final b = ref.watch(fac);
      expect(identical(a, b), isFalse);
      ref.dispose();
    });
  });

  group('Vef extras', () {
    test('getName returns non-empty debug id', () {
      final ref = TestRef();
      expect(ref.getName(), isNotEmpty);
      ref.dispose();
    });

    test('unbind does not throw for arbitrary instance', () {
      final ref = TestRef();
      final vm = SimpleVM();
      ref.unbind(vm);
      ref.dispose();
    });

    test('removePauseProvider after add does not throw', () {
      final ref = TestRef();
      final provider = AppPauseProvider();
      ref.addPauseProvider(provider);
      ref.removePauseProvider(provider);
      provider.dispose();
      ref.dispose();
    });

    test('reading with non-specific VM type throws', () {
      final ref = TestRef();
      expect(
        () => ref.read<ViewModel>(ViewModelProvider(builder: () => SimpleVM())),
        throwsA(isA<Error>()),
      );
      ref.dispose();
    });
  });
}
