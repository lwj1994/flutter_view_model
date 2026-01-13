# ViewModelProvider Migration Guide

## Overview

This guide helps you migrate from Factory-based APIs to the
declarative `Provider` family. The goal is simpler, safer, and
more consistent ViewModel creation and sharing, with fewer boilerplate
pieces.

## New Concepts

- ViewModelProvider: Declarative provider for building a ViewModel without
  arguments. Encapsulates builder and sharing rules.
- ViewModelProvider.arg: provider for building with one argument.
- ViewModelProvider.arg2/3/4: providers for building with 2/3/4 arguments.
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
final provider = ViewModelProvider<MyVM>(builder: MyVM.new);
final vm = vef.watch(provider);
```

Cached access:

```dart
// Before
final vm = watchCachedViewModel<MyVM>(key: 'k');

// After
final vm = vef.watchCached<MyVM>(key: 'k');
```

Read (non-listening):

```dart
// Before
final vm = readViewModel<MyVM>(factory: MyVmFactory());

// After
final vm = vef.read(ViewModelProvider<MyVM>(builder: MyVM.new));
```

## Examples

### Without Arguments

```dart
final provider = ViewModelProvider<CounterViewModel>(
  builder: CounterViewModel.new,
  key: 'counter',
);
final vm = vef.watch(provider);
```

### With One Argument

```dart
final userprovider = ViewModelProvider.arg<UserViewModel, String>(
  builder: (id) => UserViewModel(userId: id),
  key: (id) => 'user-$id',
  tag: (id) => 'user-$id',
);
final vm = vef.watch(userprovider('user-123'));
```

### With Two Arguments

```dart
final provider2 = ViewModelProvider.arg2<UserVM, String, int>(
  builder: (id, page) => UserVM(id, page),
  key: (id, page) => 'user-$id:$page',
);
final vm = vef.watch(provider2('u42', 1));
```

### With Three Arguments

```dart
final provider3 = ViewModelProvider.arg3<ReportVM, String, DateTime, bool>(
  builder: (id, date, force) => ReportVM(id, date, force),
);
final vm = vef.watch(provider3('rid', DateTime.now(), true));
```

### With Four Arguments

```dart
final provider4 = ViewModelProvider.arg4<TaskVM, String, int, String, bool>(
  builder: (id, priority, group, silent) => TaskVM(id, priority, group, silent),
);
final vm = vef.watch(provider4('t1', 5, 'g1', false));
```


## Legacy APIs

The following legacy methods are still available as convenience wrappers around the `vef` system. While the `vef` namespace is recommended for consistency, you can continue using these if you prefer the explicit method syntax:

- `watchViewModel(...)` (Equivalent to `vef.watch`)
- `readViewModel(...)` (Equivalent to `vef.read`)
- `watchCachedViewModel(...)` (Equivalent to `vef.watchCached`)
- `readCachedViewModel(...)` (Equivalent to `vef.readCached`)
- `listenViewModel(...)` (Equivalent to `vef.listen`)
- `listenViewModelState(...)` (Equivalent to `vef.listenState`)
- `listenViewModelStateSelect(...)` (Equivalent to `vef.listenStateSelect`)
- `maybeWatchCachedViewModel(...)` (Equivalent to `vef.maybeWatchCached`)
- `maybeReadCachedViewModel(...)` (Equivalent to `vef.maybeReadCached`)
- `recycleViewModel(vm)` (Equivalent to `vef.recycle`)

These methods are fully compatible with the new `ViewModelProvider` system and will continue to work for the foreseeable future.

## Quick Checklist

- Replace Factory instances with `ViewModelProvider` or `ViewModelProvider.arg*`.
- Swap `watchViewModel/readViewModel` to `watch/read` with providers.
- Swap cached methods to `watchCached/readCached`.
- Verify `key/tag/(deprecated) isSingleton` behavior after migration.
- Update tests and examples to use providers.
