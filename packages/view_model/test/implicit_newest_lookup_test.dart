import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class _TaggedVM with ViewModel {}

class _Binding with ViewModelBinding {}

class _EqualityOnlyTag {
  _EqualityOnlyTag(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is _EqualityOnlyTag && other.value == value;

  @override
  int get hashCode => throw StateError('tag.hashCode must not be called');
}

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

  test('unkeyed untagged cached lookup returns newest without warning', () {
    final binding = _Binding();
    addTearDown(binding.dispose);
    final olderSpec = ViewModelSpec<_TaggedVM>(
      builder: _TaggedVM.new,
      key: 'older',
    );
    final newerSpec = ViewModelSpec<_TaggedVM>(
      builder: _TaggedVM.new,
      key: 'newer',
    );
    _TaggedVM older() => binding.read(olderSpec);
    _TaggedVM newer() => binding.read(newerSpec);

    older();
    expect(ViewModel.readCached<_TaggedVM>(), same(older()));

    newer();
    // 再次访问旧实例不会改变创建顺序。
    older();
    expect(ViewModel.readCached<_TaggedVM>(), same(newer()));
    expect(ViewModel.maybeReadCached<_TaggedVM>(), same(newer()));
    expect(binding.readCached<_TaggedVM>(), same(newer()));
    expect(binding.maybeReadCached<_TaggedVM>(), same(newer()));
    expect(binding.watchCached<_TaggedVM>(), same(newer()));
    expect(binding.maybeWatchCached<_TaggedVM>(), same(newer()));

    binding.recycle(newer());
    expect(ViewModel.readCached<_TaggedVM>(), same(older()));
    expect(binding.readCached<_TaggedVM>(), same(older()));
    expect(lookupWarnings(), isEmpty);
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

  test('tag warnings preserve equality-only lookup without hashing tags', () {
    final binding = _Binding();
    addTearDown(binding.dispose);
    final queryTag = _EqualityOnlyTag('shared');
    final newestSpec = ViewModelSpec<_TaggedVM>(
      builder: _TaggedVM.new,
      key: 'newest',
      tag: _EqualityOnlyTag('shared'),
    );
    _TaggedVM newest() => binding.read(newestSpec);

    binding.read(ViewModelSpec<_TaggedVM>(
      builder: _TaggedVM.new,
      key: 'older',
      tag: _EqualityOnlyTag('shared'),
    ));
    newest();

    expect(ViewModel.readCached<_TaggedVM>(tag: queryTag), same(newest()));
    expect(ViewModel.maybeReadCached<_TaggedVM>(tag: queryTag), same(newest()));
    expect(binding.readCached<_TaggedVM>(tag: queryTag), same(newest()));
    expect(binding.maybeReadCached<_TaggedVM>(tag: queryTag), same(newest()));
    expect(binding.watchCached<_TaggedVM>(tag: queryTag), same(newest()));
    expect(binding.maybeWatchCached<_TaggedVM>(tag: queryTag), same(newest()));
    expect(lookupWarnings(), hasLength(1));
    expect(lookupWarnings().single, contains('matched 2 instances'));

    // 值相等的另一个 tag 仍匹配同一批实例，但提示按对象身份独立去重。
    final equalTag = _EqualityOnlyTag('shared');
    expect(binding.readCached<_TaggedVM>(tag: equalTag), same(newest()));
    expect(binding.readCached<_TaggedVM>(tag: equalTag), same(newest()));
    expect(lookupWarnings(), hasLength(2));
  });
}
