import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class _TaggedVM with ViewModel {}

class _Binding with ViewModelBinding {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    ViewModel.reset();
  });

  List<String> lookupWarnings() => logs
      .where((log) => log.contains('cached lookup of _TaggedVM'))
      .toList(growable: false);

  test('unkeyed untagged cached lookup warns once per type', () {
    final binding = _Binding();
    addTearDown(binding.dispose);
    final vm = binding.read(
      ViewModelSpec<_TaggedVM>(builder: _TaggedVM.new, key: 'a'),
    );

    expect(ViewModel.readCached<_TaggedVM>(), same(vm));
    expect(binding.readCached<_TaggedVM>(), same(vm));

    final warnings = lookupWarnings();
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('deprecation'));
  });

  test('tag lookup warns only when it is ambiguous', () {
    final binding = _Binding();
    addTearDown(binding.dispose);
    binding.read(
      ViewModelSpec<_TaggedVM>(builder: _TaggedVM.new, key: 'a', tag: 't'),
    );

    binding.readCached<_TaggedVM>(tag: 't');
    expect(lookupWarnings(), isEmpty);

    final newest = binding.read(
      ViewModelSpec<_TaggedVM>(builder: _TaggedVM.new, key: 'b', tag: 't'),
    );
    expect(binding.readCached<_TaggedVM>(tag: 't'), same(newest));
    expect(binding.readCached<_TaggedVM>(tag: 't'), same(newest));

    final warnings = lookupWarnings();
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('matched 2 instances'));
  });

  test('key lookup and spec resolution never warn', () {
    final binding = _Binding();
    addTearDown(binding.dispose);
    final spec = ViewModelSpec<_TaggedVM>(builder: _TaggedVM.new, key: 'a');
    binding.read(spec);
    binding.watch(spec);
    binding.readCached<_TaggedVM>(key: 'a');

    expect(lookupWarnings(), isEmpty);
  });
}
