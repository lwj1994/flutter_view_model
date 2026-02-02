# ViewModelSpec Migration Guide

## Overview

This guide helps you migrate from Factory-based APIs to the
declarative `Spec` family. The goal is simpler, safer, and
more consistent ViewModel creation and sharing, with fewer boilerplate
pieces.

## New Concepts

- ViewModelSpec: Declarative spec for building a ViewModel without
  arguments. Encapsulates builder and sharing rules.
- ViewModelSpec.arg: spec for building with one argument.
- ViewModelSpec.arg2/3/4: specs for building with 2/3/4 arguments.
- Sharing rules: `key`, `tag`, (deprecated) `isSingleton`.

## Key Semantics

- `key`: Unique identifier to reuse the same instance across widgets.
- `tag`: Label to group or discover the latest instance by tag.
- `isSingleton` (Deprecated): Convenience to reuse one instance when no explicit key
  is provided. Use `key` instead. Explicit `key` has higher priority than `isSingleton`.

## API Changes

Before:

```dart
final vm = watchViewModel<MyVM>(
  factory: DefaultViewModelFactory<MyVM>(builder: MyVM.new),
);
```

After:

```dart
final spec = ViewModelSpec<MyVM>(builder: MyVM.new);
final vm = viewModelBinding.watch(spec);
```

Cached access:

```dart
// Before
final vm = watchCachedViewModel<MyVM>(key: 'k');

// After
final vm = viewModelBinding.watchCached<MyVM>(key: 'k');
```

Read (non-listening):

```dart
// Before
final vm = readViewModel<MyVM>(factory: MyVmFactory());

// After
final vm = viewModelBinding.read(ViewModelSpec<MyVM>(builder: MyVM.new));
```

## Examples

### Without Arguments

```dart
final spec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
  key: 'counter',
);
final vm = viewModelBinding.watch(spec);
```

### With One Argument

```dart
final userSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: (id) => UserViewModel(userId: id),
  key: (id) => 'user-$id',
  tag: (id) => 'user-$id',
);
final vm = viewModelBinding.watch(userSpec('user-123'));
```

### With Two Arguments

```dart
final spec2 = ViewModelSpec.arg2<UserVM, String, int>(
  builder: (id, page) => UserVM(id, page),
  key: (id, page) => 'user-$id:$page',
);
final vm = viewModelBinding.watch(spec2('u42', 1));
```

### With Three Arguments

```dart
final spec3 = ViewModelSpec.arg3<ReportVM, String, DateTime, bool>(
  builder: (id, date, force) => ReportVM(id, date, force),
);
final vm = viewModelBinding.watch(spec3('rid', DateTime.now(), true));
```

### With Four Arguments

```dart
final spec4 = ViewModelSpec.arg4<TaskVM, String, int, String, bool>(
  builder: (id, priority, group, silent) => TaskVM(id, priority, group, silent),
);
final vm = viewModelBinding.watch(spec4('t1', 5, 'g1', false));
```


## Legacy APIs

The following legacy methods are still available as convenience wrappers around the `viewModelBinding` system. While the `viewModelBinding` namespace is recommended for consistency, you can continue using these if you prefer the explicit method syntax:

- `watchViewModel(...)` (Equivalent to `viewModelBinding.watch`)
- `readViewModel(...)` (Equivalent to `viewModelBinding.read`)
- `watchCachedViewModel(...)` (Equivalent to `viewModelBinding.watchCached`)
- `readCachedViewModel(...)` (Equivalent to `viewModelBinding.readCached`)
- `listenViewModel(...)` (Equivalent to `viewModelBinding.listen`)
- `listenViewModelState(...)` (Equivalent to `viewModelBinding.listenState`)
- `listenViewModelStateSelect(...)` (Equivalent to `viewModelBinding.listenStateSelect`)
- `maybeWatchCachedViewModel(...)` (Equivalent to `viewModelBinding.maybeWatchCached`)
- `maybeReadCachedViewModel(...)` (Equivalent to `viewModelBinding.maybeReadCached`)
- `recycleViewModel(vm)` (Equivalent to `viewModelBinding.recycle`)

These methods are fully compatible with the new `ViewModelSpec` system and will continue to work for the foreseeable future.

## Quick Checklist

- Replace Factory instances with `ViewModelSpec` or `ViewModelSpec.arg*`.
- Swap `watchViewModel/readViewModel` to `watch/read` with specs.
- Swap cached methods to `watchCached/readCached`.
- Verify `key/tag/(deprecated) isSingleton` behavior after migration.
- Update tests and examples to use specs.
