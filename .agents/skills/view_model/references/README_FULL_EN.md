# view_model — State Management, Dependency Injection, and Module Architecture

| `view_model` | `view_model_annotation` | `view_model_generator` | Coverage |
| :---: | :---: | :---: | :---: |
| [![view_model version](https://img.shields.io/pub/v/view_model.svg)](https://pub.dev/packages/view_model) | [![view_model_annotation version](https://img.shields.io/pub/v/view_model_annotation.svg)](https://pub.dev/packages/view_model_annotation) | [![view_model_generator version](https://img.shields.io/pub/v/view_model_generator.svg)](https://pub.dev/packages/view_model_generator) | [![codecov](https://codecov.io/gh/lwj1994/flutter_view_model/branch/main/graph/badge.svg)](https://app.codecov.io/gh/lwj1994/flutter_view_model) |

[简体中文](./README_ZH.md)

**More than state management: view_model is a Flutter architecture for
dependency injection, functional-module composition, and automatic lifecycle
management.**

Model each functional unit—UI state, services, repositories, coordinators, or
domain capabilities—as a ViewModel. ViewModels inject and compose one another
through `viewModelBinding`, while the binding system resolves only the nodes
whose getters are accessed, reuses instances within its scope, and disposes
them automatically.

```yaml
dependencies:
  view_model: ^1.0.0
```

## Install Skill

```bash
npx skills add https://github.com/lwj1994/flutter_view_model --skill view_model
```

---

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Two Core Mixins](#two-core-mixins)
- [Getting Started](#getting-started)
- [ViewModel](#viewmodel)
  - [Basic ViewModel](#basic-viewmodel)
  - [StateViewModel](#stateviewmodel)
  - [ChangeNotifierViewModel](#changenotifierviewmodel)
- [ViewModelSpec](#viewmodelspec)
- [Widget Integration](#widget-integration)
  - [ViewModelStateMixin](#viewmodelstatemixin)
  - [ViewModelBuilder](#viewmodelbuilder)
  - [ViewModelStatelessMixin](#viewmodelstatelessmixin)
- [viewModelBinding API](#viewmodelbinding-api)
  - [watch vs read](#watch-vs-read)
  - [listen / listenState / listenStateSelect](#listen--listenstate--listenstateselect)
  - [Lifecycle Control](#lifecycle-control)
- [Instance Sharing](#instance-sharing)
  - [key-based Sharing](#key-based-sharing)
  - [tag-based Lookup](#tag-based-lookup)
  - [aliveForever Retention](#aliveforever-retention)
  - [Static Global Access](#static-global-access)
- [ViewModelBinding in Any Class](#viewmodelbinding-in-any-class)
- [ViewModel-to-ViewModel Dependencies](#viewmodel-to-viewmodel-dependencies)
- [Fine-Grained Reactivity](#fine-grained-reactivity)
  - [StateViewModelSelector](#stateviewmodelselector)
  - [StateViewModelValueWatcher](#stateviewmodelvaluewatcher)
  - [Deprecated: ObservableValue & ObserverBuilder](#deprecated-observablevalue--observerbuilder)
- [Pause / Resume](#pause--resume)
- [Lifecycle Details](#lifecycle-details)
  - [Reference Counting (Binding)](#reference-counting-binding)
  - [Resource Cleanup](#resource-cleanup)
  - [ViewModelLifecycle Observer](#viewmodellifecycle-observer)
- [Configuration](#configuration)
- [Testing](#testing)
- [Code Generation](#code-generation)
- [DevTools Extension](#devtools-extension)
- [view_model vs riverpod](#view_model-vs-riverpod)

---

## Architecture Overview

The library is organized in three layers:

```
┌─────────────────────────────────────────────────┐
│              Widget / Consumer Layer            │
│  ViewModelStateMixin, ViewModelBuilder, ...     │
└───────────────────┬─────────────────────────────┘
                    │ watch / read
┌───────────────────▼─────────────────────────────┐
│              ViewModelBinding Layer             │
│  Bridges consumers to the instance registry.    │
│  Both watch() and read() perform binding.       │
│  watch() additionally registers a listener.     │
│  Manages pause/resume and Zone-based DI.        │
└───────────────────┬─────────────────────────────┘
                    │ getInstance → bind(bindingId)
┌───────────────────▼─────────────────────────────┐
│           Instance Management Layer             │
│  InstanceManager ─► Store<T> ─► InstanceHandle  │
│  Type-keyed registry. Each handle tracks a      │
│  list of bindingIds (reference count).          │
│  Auto-disposes when bindingIds becomes empty.   │
└─────────────────────────────────────────────────┘
```

**Key mechanics:**

1. Each `ViewModelBinding` (typically one per widget) has a unique `id` string.
2. Both `watch(spec)` and `read(spec)` obtain or create the ViewModel instance, then call `bind(id)` on the `InstanceHandle` to add the binding's `id` to the handle's `bindingIds` list. This is the **reference count**. Both methods bind; the difference is that `watch` also attaches a change listener.
3. When the `ViewModelBinding` disposes, it calls `unbind(id)` on every handle it bound to. If a handle's `bindingIds` becomes empty (and `aliveForever` is false), the ViewModel is automatically disposed.
4. `watch` additionally calls `_addListener`, which registers a callback on the ViewModel via `listen()`. When the ViewModel calls `notifyListeners()`, this callback invokes `onUpdate()` on the binding. For `WidgetViewModelBinding`, `onUpdate()` calls `setState()` to trigger a rebuild.
5. ViewModel-to-ViewModel dependencies are resolved through Dart **Zones**: when a ViewModel is constructed via `_createViewModel`, the parent `ViewModelBinding` is stored in a zone value using `runWithBinding()`. Inside the new ViewModel's constructor, accessing `viewModelBinding` resolves from the zone, so nested dependencies bind to the same root binding.

---

## Two Core Mixins

The entire library revolves around two mixins that can be applied to **any Dart class**:

### `with ViewModel` — Makes a class a managed instance

Any class that mixes in `ViewModel` gains:
- Lifecycle callbacks (`onCreate`, `onBind`, `onUnbind`, `onDispose`)
- Listener support (`notifyListeners()`, `listen()`, `update()`)
- Access to other ViewModels via `viewModelBinding` (resolved from the parent binding through Zones)
- Automatic disposal registration via `addDispose()`

```dart
class UserRepository with ViewModel { /* ... */ }
class AnalyticsService with ViewModel { /* ... */ }
class CartViewModel with ViewModel { /* ... */ }
```

### `with ViewModelBinding` — Makes a class able to access ViewModels

Any class that mixes in `ViewModelBinding` becomes a **binding host** — it can create, bind to, and manage ViewModel instances. It's not limited to widgets. Widget mixins like `ViewModelStateMixin` are simply thin wrappers around `ViewModelBinding` that bridge `onUpdate()` to `setState()`.

```dart
// A plain Dart class that manages ViewModels
class AppInitializer with ViewModelBinding {
  Future<void> run() async {
    await viewModelBinding.read(configSpec).load();
    await viewModelBinding.read(authSpec).restoreSession();
  }
}

// A background service
class SyncService with ViewModelBinding {
  void start() {
    viewModelBinding.watch(syncSpec).startPeriodicSync();
  }

  @override
  void onUpdate() {
    // react to ViewModel changes without any widget
  }
}
```

These two mixins together form the foundation: `ViewModel` is the managed side, `ViewModelBinding` is the managing side. Every other API in the library is built on this relationship.

---

## Getting Started

```dart
import 'package:view_model/view_model.dart';

// 1. Define a ViewModel
class CounterViewModel with ViewModel {
  int count = 0;
  void increment() => update(() => count++);
}

// 2. Declare a spec (factory definition)
final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);

// 3. Use in a widget
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  CounterViewModel get vm => viewModelBinding.watch(counterSpec);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: vm.increment,
      child: Text('${vm.count}'),
    );
  }
}
```

No root wrapper widget, no `ChangeNotifierProvider`, no `ProviderScope`. The mixin gives you `viewModelBinding`; `watch` wires up instance creation, binding, listener registration, and disposal.

---

## ViewModel

### Basic ViewModel

Mix `ViewModel` into any class to give it lifecycle awareness and listener support. `ViewModel` implements `Listenable`, so it works with Flutter's `ListenableBuilder` and `AnimatedBuilder` out of the box.

```dart
class TodoViewModel with ViewModel {
  final _items = <String>[];
  List<String> get items => List.unmodifiable(_items);

  void add(String item) {
    _items.add(item);
    notifyListeners(); // manually notify
  }

  // update() is a convenience: runs the block, then calls notifyListeners()
  void remove(int index) => update(() => _items.removeAt(index));
}
```

`update()` preserves synchronous notification for a synchronous block: listeners
have already run when the call returns. If the block returns a `Future`, the
notification runs after that future completes successfully. A synchronous throw
or failed future is forwarded to the caller and does not notify listeners.

### StateViewModel

`StateViewModel<T>` manages an immutable state object of type `T`. Internally it uses a `StreamController<DiffState<T>>` to broadcast `(previousState, currentState)` pairs. This unlocks `listenState` and `listenStateSelect` for selective listening.

```dart
class UserState {
  final String name;
  final int age;
  final bool loading;
  const UserState({this.name = '', this.age = 0, this.loading = false});
}

class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: const UserState());

  Future<void> load() async {
    setState(UserState(loading: true));
    final user = await api.fetchUser();
    setState(UserState(name: user.name, age: user.age));
  }
}
```

Full-state equality uses the ViewModel constructor's local `equals`, then the
global `ViewModelConfig.equals` fallback, and finally `identical()` when neither
is configured (see [Configuration](#configuration)).

`setState` is the only API that emits a state diff. Calling `notifyListeners()`
only refreshes broad ViewModel listeners; it does not replay the last diff or
invoke `listenState` / `listenStateSelect` again. Selected values use the global
`ViewModelConfig.equals` fallback when configured, then `==`. An explicit
`equals` passed to `listenStateSelect` takes priority over the global fallback.

### ChangeNotifierViewModel

If you need to extend `ChangeNotifier` (e.g., to pass the ViewModel directly to `AnimatedBuilder` or `ValueListenableBuilder`), use `ChangeNotifierViewModel`:

```dart
class MyViewModel extends ChangeNotifierViewModel {
  int value = 0;
  void inc() { value++; notifyListeners(); }
}
```

---

## ViewModelSpec

`ViewModelSpec` is a declarative factory that tells the system *how to build* a ViewModel and *how to identify it* for caching.

```dart
// No arguments
final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);

// With a fixed key (shared globally)
final authSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
  key: 'auth',
  aliveForever: true,
);

// With one argument: key and tag are computed from the argument
final userSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user-$userId',
);

// Two arguments
final chatSpec = ViewModelSpec.arg2<ChatViewModel, String, int>(
  builder: (roomId, limit) => ChatViewModel(roomId, limit),
  key: (roomId, limit) => 'chat-$roomId',
);

// arg3 and arg4 are also available
```

Calling `userSpec('abc')` returns a `ViewModelFactory<UserViewModel>` that you can pass to `watch` / `read`.

An instance's identity is the combination of the resolved generic ViewModel
type `T` and its effective `key`; the builder's runtime result type is not part
of identity, and `tag` is only a grouping/lookup label. When factory `key()`
returns `null`, the current `ViewModelBinding` supplies a private default key,
so repeated `watch`/`read` calls for the same `T` reuse one instance within
that binding while different bindings remain isolated. Set a key when you need
to:

- share an instance across bindings;
- distinguish multiple instances of the same `T` in one binding; or
- give shared instances a stable identity across all resolving bindings.

A key does not keep an instance alive; retention is controlled separately by
`aliveForever`.

In debug mode, resolving different specs with the same `T` and effective key
from one binding emits a warning: instance identity ignores the builder, so the
second builder will not run. Give logically different specs distinct keys.

Internally, `ViewModelSpec` extends `ViewModelFactory<T>`, which defines:
- `build()` — creates the instance
- `key()` — cache key (same resolved `T` + same key = same identity)
- `tag()` — logical grouping label
- `aliveForever()` — whether to skip auto-disposal

---

## Widget Integration

### ViewModelStateMixin

The primary way to use ViewModels in widgets. Mix it into `State<T>`:

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  MyViewModel get vm => viewModelBinding.watch(mySpec);

  @override
  Widget build(BuildContext context) {
    return Text(vm.data);
  }
}
```

The mixin:
- Creates a `WidgetViewModelBinding` whose `onUpdate()` calls `setState()`.
- Registers three default `PauseProvider`s (route, ticker mode, app lifecycle).
- Disposes everything (unbinds all handles) in `State.dispose()`.

### ViewModelBuilder

A convenience widget that internally uses `ViewModelStateMixin`, so you don't need a custom `State` class:

```dart
ViewModelBuilder<CounterViewModel>(
  counterSpec,
  builder: (vm) => Text('${vm.count}'),
)
```

For fetching an already-existing (cached) ViewModel:

```dart
CachedViewModelBuilder<CounterViewModel>(
  shareKey: 'my-counter',
  builder: (vm) => Text('${vm.count}'),
)
```

### ViewModelStatelessMixin

Mix into `StatelessWidget` for lightweight usage. The mixin creates a custom `Element` that owns the `WidgetViewModelBinding`:

```dart
class MyWidget extends StatelessWidget with ViewModelStatelessMixin {
  MyViewModel get vm => viewModelBinding.watch(mySpec);
  MyWidget({super.key});

  @override
  Widget build(BuildContext context) => Text(vm.data);
}
```

> Caveat: if the same widget instance is mounted in multiple locations simultaneously, this won't work correctly. Prefer `ViewModelStateMixin` when in doubt.

---

## viewModelBinding API

`viewModelBinding` is the accessor provided by `ViewModelStateMixin`, `ViewModelStatelessMixin`, the `ViewModel` mixin, or any class that mixes in `ViewModelBinding`. It exposes `ViewModelBindingInterface` with these methods:

### watch vs read

Both `watch` and `read` **bind** the current `ViewModelBinding` to the ViewModel (adding its `bindingId` to the handle's `bindingIds`). Both contribute to the reference count that keeps the ViewModel alive. The difference is only in listener registration:

| | Creates if absent? | Binds? | Listens for changes? | Triggers rebuild? |
|---|---|---|---|---|
| `watch(spec)` | Yes | Yes | Yes | Yes |
| `read(spec)` | Yes | Yes | No | No |

```dart
// In initState or build — want rebuilds when ViewModel changes
final vm = viewModelBinding.watch(spec);

// In an event handler — just need to call a method, no rebuild needed
void _onTap() {
  viewModelBinding.read(spec).doSomething();
}
```

### listen / listenState / listenStateSelect

Fire-and-forget listeners that are automatically cleaned up when the binding disposes. These use `read` internally (bind without triggering widget rebuild) and then attach custom callbacks:

```dart
// General change callback
viewModelBinding.listen(authSpec, onChanged: () {
  print('auth changed');
});

// StateViewModel: full state diff
viewModelBinding.listenState(userSpec, onChanged: (UserState? prev, UserState curr) {
  print('user state changed');
});

// StateViewModel: selected property with a custom equality rule
viewModelBinding.listenStateSelect(
  userSpec,
  selector: (UserState s) => s.name,
  equals: (previous, current) => previous == current,
  onChanged: (String? prevName, String currName) {
    print('name changed to $currName');
  },
);
```

Use `listenStateSelect` without `equals` for the global
`ViewModelConfig.equals` fallback, or `==` when the global comparator is `null`.
Pass its optional strongly typed `equals` when this selector needs a local rule;
the local rule takes priority over the global fallback.

For field-level updates, prefer `read` plus selector-based listeners. Avoid
pairing `listenStateSelect` with `watch` on the same ViewModel, or you'll keep
the broad ViewModel listener and lose the point of selective updates.

### Lifecycle Control

Routine cleanup is automatic when a binding is disposed. The explicit
lifecycle controls are:

- `recycle(vm)` is an advanced escape hatch with dangerous global impact: it
  removes every owner and force-disposes the shared cached instance, including
  an `aliveForever` instance. Use it only when that global effect is explicitly
  intended. The next `watch`/`read` creates a fresh instance.
- `recreate(vm, builder: ...)` replaces the instance while preserving active
  binding relationships. Without `builder`, the original factory is reused.

Custom selector equality is the optional `equals` argument on
`listenStateSelect`. `recreate` remains a separate optional capability: a type
that directly implements `ViewModelBindingInterface` opts in by also
implementing `ViewModelBindingRecreateCapability`. Calling `recreate` through
the interface extension on an unsupported implementation throws
`UnsupportedError`.

> **After `recycle`, the old object is disposed.** Every consumer—especially
> other owners of a shared instance—must resolve the ViewModel through a
> resolver getter that calls `watch`/`read` on every access. Owners are notified,
> and the getter's next access misses the removed cache entry and creates the
> fresh instance normally. A long-lived field keeps pointing at the disposed
> object and can cause leaks or failures.

```dart
MyViewModel get vm => viewModelBinding.watch(mySpec); // resolve on each access

MyViewModel replaceInPlace() => viewModelBinding.recreate(vm);

// Advanced escape hatch only; this affects every owner:
void resetGlobally() => viewModelBinding.recycle(vm);
// Do not keep using the old value; the next `vm` getter access resolves fresh.
```

---

## Instance Sharing

### key-based Sharing

When a `ViewModelSpec<T>` has a `key`, any binding that resolves the same `T`
with an equal key gets the **same instance**. Each binding adds its own
`bindingId` to the handle — the instance stays alive until all bindings unbind.

```dart
final spec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
  key: 'shared-counter',
);

// Widget A binds → bindingIds = ['A#123']
viewModelBinding.watch(spec);

// Widget B binds → bindingIds = ['A#123', 'B#456']
viewModelBinding.watch(spec);
```

When factory `key()` returns `null`, the binding supplies a private default
key. This gives one instance per resolved generic ViewModel type `T` within
that binding, isolated from other bindings. To create multiple instances of
the same `T` in one binding, give their specs distinct keys.

### tag-based Lookup

`tag` is a grouping label. Multiple instances can share the same tag:

```dart
final spec = ViewModelSpec<ItemVM>(
  builder: () => ItemVM(),
  tag: 'active-items',
);
```

### aliveForever Retention

Set `aliveForever: true` to skip automatic disposal when the handle's
`bindingIds` becomes empty. The instance remains cached until it is explicitly
force-disposed with `recycle` or the process ends:

```dart
final authSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
  key: 'auth',
  aliveForever: true,
);
```

## ViewModelBinding in Any Class

`ViewModelBinding` is not just for widgets — any Dart class can mix it in to gain the full `viewModelBinding` API (`watch`, `read`, `listen`, etc.). Widget mixins like `ViewModelStateMixin` are simply thin wrappers around `ViewModelBinding` that bridge `onUpdate()` to `setState()`.

**App initialization:**

```dart
class AppBootstrap with ViewModelBinding {
  Future<void> run() async {
    final config = viewModelBinding.read(configSpec);
    await config.load();

    final auth = viewModelBinding.read(authSpec);
    await auth.restoreSession();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = AppBootstrap();
  await bootstrap.run();
  bootstrap.dispose(); // unbind when done
  runApp(MyApp());
}
```

**Background services:**

```dart
class SyncService with ViewModelBinding {
  void start() {
    viewModelBinding.watch(syncSpec).startPeriodicSync();
  }

  @override
  void onUpdate() {
    // react to ViewModel changes without any widget
    print('sync state changed');
  }
}
```

**Pure Dart tests (no testWidgets needed):**

```dart
test('counter increments', () {
  final binding = ViewModelBinding();
  final vm = binding.watch(counterSpec);

  expect(vm.count, 0);
  vm.increment();
  expect(vm.count, 1);

  binding.dispose();
});
```

You can override `onUpdate()`, `onPause()`, `onResume()` in your class. You can also add custom `PauseProvider`s via `addPauseProvider()`.

---

## ViewModel-to-ViewModel Dependencies

Inside a ViewModel, `viewModelBinding` resolves through the owner binding
currently selected by `refHandler`: the first remaining owner, not necessarily
the caller's root. Expose nested ViewModels through resolver getters that call
`watch`/`read` on every access, so each access uses that selected binding. Within
one binding, the registry still returns the same managed instance:

```dart
class OrderViewModel with ViewModel {
  CartViewModel get cart => viewModelBinding.read(cartSpec);
  UserViewModel get user => viewModelBinding.read(userSpec);

  double get total => cart.items.fold(0, (sum, i) => sum + i.price);
}
```

Prefer a getter over `late final`, a constructor-cached field, or `??=`. This
also avoids retaining a disposed dependency after `recycle` or a root-binding
handoff.

Reactive dependencies use `watch`; when the dependency notifies, the selected
root binding's `onUpdate` fires:

```dart
class DashboardViewModel with ViewModel {
  AuthViewModel get auth => viewModelBinding.watch(authSpec);
}
```

Side-effect dependencies with `listen`:

```dart
class ChatViewModel with ViewModel {
  ChatViewModel() {
    viewModelBinding.listenState(authSpec, onChanged: (prev, curr) {
      if (curr.isLoggedOut) clearMessages();
    });
  }
}
```

When a root binding is disposed, it releases every dependency that it actually
resolved. If no other binding holds those handles, they are disposed as well.
Getter declarations alone create nothing; a dependency is created or reused
only when its getter is evaluated.

> **Shared-parent boundary:** a keyed parent can be held by multiple root
> bindings, but a child resolved through that parent is not automatically bound
> to every one of them. If the root that resolved the child is disposed, the
> child may be disposed while the parent survives. A resolver getter avoids
> retaining that disposed child and re-resolves through the next owner selected
> by `refHandler`, but the child may be recreated and lose its previous state.
> Prefer an unkeyed composite parent plus keyed leaf dependencies that every
> root resolves, or a dedicated application-level binding owner when continuity
> is required.

---

## Fine-Grained Reactivity

### StateViewModelSelector

For new code, prefer one strongly typed selector and selected builder value.
Use a Dart record to select several fields as one update boundary. The selected
value uses global `ViewModelConfig.equals` when configured and otherwise `==`;
pass a typed `equals` to override that fallback locally:

```dart
StateViewModelSelector<UserState, ({String name, int age})>(
  viewModel: vm,
  selector: (state) => (name: state.name, age: state.age),
  builder: (context, value) => Text('${value.name}, ${value.age}'),
)
```

### StateViewModelValueWatcher

This compatibility widget accepts a list of untyped selectors and only rebuilds
when at least one selected value changes:

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  // Use read — the ValueWatcher handles its own subscriptions internally.
  // Avoid watch here, or the whole ViewModel will still trigger rebuilds.
  UserViewModel get vm => viewModelBinding.read(userSpec);

  @override
  Widget build(BuildContext context) {
    return StateViewModelValueWatcher<UserState>(
      viewModel: vm,
      selectors: [(s) => s.name, (s) => s.age],
      builder: (state) => Text('${state.name}, age ${state.age}'),
    );
  }
}
```

Internally, each selector is wrapped into a `listenStateSelect` call on the
ViewModel. The widget only rebuilds when at least one selector's output differs
from its previous value according to global `ViewModelConfig.equals`, or `==`
when the global comparator is `null`. To keep updates truly fine-grained, read
the ViewModel with `read` and let the selector mechanism drive rebuilds instead
of also using `watch`.

### Deprecated: ObservableValue & ObserverBuilder

`ObservableValue` and `ObserverBuilder` / `ObserverBuilder2` /
`ObserverBuilder3` are deprecated and scheduled for removal in 2.0.0. They are
convenience wrappers around a hidden `StateViewModel`, rather than a core state
management capability.

For a widget-local reactive value, use Flutter's `ValueNotifier` and
`ValueListenableBuilder`, and dispose the notifier with its owner:

```dart
class ThemeToggle extends StatefulWidget {
  const ThemeToggle({super.key});

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  final ValueNotifier<bool> _isDarkMode = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDarkMode,
      builder: (context, isDarkMode, child) {
        return IconButton(
          icon: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
          onPressed: () => _isDarkMode.value = !isDarkMode,
        );
      },
    );
  }

  @override
  void dispose() {
    _isDarkMode.dispose();
    super.dispose();
  }
}
```

For state that needs view_model lifecycle management, model it explicitly with
`StateViewModel` and `ViewModelSpec`. This example uses a keyed non-widget
binding owner so producers can read and update the state before the observing
widget mounts or while it is unmounted:

```dart
class ThemeModeViewModel extends StateViewModel<bool> {
  ThemeModeViewModel() : super(state: false);

  void setDarkMode(bool value) => setState(value);
}

final themeModeSpec = ViewModelSpec<ThemeModeViewModel>(
  builder: ThemeModeViewModel.new,
  key: 'theme-dark',
);

class ThemeModeOwner with ViewModelBinding {
  ThemeModeViewModel get themeMode =>
      viewModelBinding.read(themeModeSpec);

  void setDarkMode(bool value) => themeMode.setDarkMode(value);
}

class ThemeModeExample extends StatefulWidget {
  const ThemeModeExample({super.key});

  @override
  State<ThemeModeExample> createState() => _ThemeModeExampleState();
}

class _ThemeModeExampleState extends State<ThemeModeExample> {
  final ThemeModeOwner _owner = ThemeModeOwner();

  @override
  void initState() {
    super.initState();
    // Creates and updates the instance before the observing child mounts.
    _owner.setDarkMode(true);
  }

  @override
  Widget build(BuildContext context) => const ThemeModeButton();

  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }
}

class ThemeModeButton extends StatefulWidget {
  const ThemeModeButton({super.key});

  @override
  State<ThemeModeButton> createState() => _ThemeModeButtonState();
}

class _ThemeModeButtonState extends State<ThemeModeButton>
    with ViewModelStateMixin {
  ThemeModeViewModel get themeMode =>
      viewModelBinding.watch(themeModeSpec);

  @override
  Widget build(BuildContext context) {
    final viewModel = themeMode;
    return IconButton(
      icon: Icon(viewModel.state ? Icons.dark_mode : Icons.light_mode),
      onPressed: () => viewModel.setDarkMode(!viewModel.state),
    );
  }
}
```

`ThemeModeExample` demonstrates the ownership boundary: it updates the state
before `ThemeModeButton` mounts, retains it while the child is absent, and
disposes the non-widget owner when the scope ends. An application, service, or
bootstrap scope follows the same pattern. The key is needed here for
cross-binding sharing; it is also required when distinguishing multiple
same-`T` instances inside one binding. It does not replace an owner or keep
the instance alive by itself. Use `aliveForever` only for intentional
process-lifetime retention when you also accept either process-end cleanup or
the dangerous global impact of the advanced `recycle` escape hatch.

When migrating `ObserverBuilder2` or `ObserverBuilder3`, prefer one state object
that contains the related values. This keeps ownership and update boundaries
explicit instead of assembling application state from standalone observables.

---

## Pause / Resume

When a widget is not visible, there's no point rebuilding it. The library automatically pauses ViewModel update delivery in three scenarios:

| Provider | Pauses when | Resumes when |
|---|---|---|
| `PageRoutePauseProvider` | Another route is pushed on top (`didPushNext`) | The covering route pops (`didPopNext`) |
| `TickerModePauseProvider` | `TickerMode` is `false` (e.g., hidden tab in `TabBarView`) | `TickerMode` is `true` again |
| `AppPauseProvider` | App enters `AppLifecycleState.hidden` | App enters `AppLifecycleState.resumed` |

The `PauseAwareController` aggregates all providers: if **any** provider signals "pause", the binding is paused. While paused, incoming `notifyListeners()` calls set a `_hasMissedUpdates` flag instead of calling `onUpdate()`. When all providers signal "resume", one catch-up `onUpdate()` fires.

**Setup**: for `PageRoutePauseProvider` to work, register the route observer:

```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
)
```

You can add custom pause providers:

```dart
class MyCustomPauseProvider with ViewModelBindingPauseProvider {
  void onScreenOff() => pause();
  void onScreenOn() => resume();
}

// In initState or any ViewModelBinding host
viewModelBinding.addPauseProvider(myProvider);
```

---

## Lifecycle Details

### Reference Counting (Binding)

Each `InstanceHandle` maintains a `bindingIds` list — this is the reference count. Both `watch` and `read` add the caller's `bindingId` to this list via `bind()`. The difference is only that `watch` also registers a listener.

```
read  from Binding A  →  bind('A#123')  →  bindingIds = ['A#123']
watch from Binding B  →  bind('B#456')  →  bindingIds = ['A#123', 'B#456']
Binding A disposes    →  unbind('A#123') →  bindingIds = ['B#456']
Binding B disposes    →  unbind('B#456') →  bindingIds = []  →  auto-dispose
```

The full lifecycle sequence:

```
ViewModelFactory.build()
       │
       ▼
   onCreate(arg)            ← InstanceHandle created, stored in Store<T>
       │
       ▼
   onBind(arg, bindingId)   ← a ViewModelBinding binds (via watch or read)
       │
       ▼
   [active: notifyListeners(), setState(), etc.]
       │
       ▼
   onUnbind(arg, bindingId) ← unbound by dispose or recycle
       │
       ▼
   (if bindingIds is empty and not aliveForever)
       │
       ▼
   onDispose(arg)           ← InstanceHandle nullifies the instance
       │
       ▼
   dispose()                ← your cleanup code runs
```

### Resource Cleanup

Register cleanup callbacks with `addDispose`. They run in order during `onDispose`:

```dart
class StreamViewModel with ViewModel {
  StreamViewModel() {
    final subscription = someStream.listen((_) => notifyListeners());
    addDispose(subscription.cancel);
  }
}
```

You can also override `dispose()` directly:

```dart
@override
void dispose() {
  _controller.close();
  super.dispose();
}
```

### ViewModelLifecycle Observer

Register global observers to monitor all ViewModel lifecycle events (creation, binding, unbinding, disposal):

```dart
class DebugLifecycle extends ViewModelLifecycle {
  @override
  void onCreate(ViewModel vm, InstanceArg arg) {
    print('[+] ${vm.runtimeType} created (key=${arg.key})');
  }

  @override
  void onBind(ViewModel vm, InstanceArg arg, String bindingId) {
    print('[~] ${vm.runtimeType} bound by $bindingId');
  }

  @override
  void onUnbind(ViewModel vm, InstanceArg arg, String bindingId) {
    print('[~] ${vm.runtimeType} unbound by $bindingId');
  }

  @override
  void onDispose(ViewModel vm, InstanceArg arg) {
    print('[-] ${vm.runtimeType} disposed');
  }
}

void main() {
  ViewModel.initialize(lifecycles: [DebugLifecycle()]);
  runApp(MyApp());
}
```

You can also add/remove lifecycle observers dynamically:

```dart
final remove = ViewModel.addLifecycle(myObserver);
// later
remove();
```

---

## Configuration

Call `ViewModel.initialize()` once at app startup. Subsequent calls are ignored.

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      // Enable debug logging
      isLoggingEnabled: true,

      // Global equality fallback (default: null)
      // Full state ultimately falls back to identical(); selectors to ==.
      equals: (a, b) => a == b,

      // Global error handler for listener and disposal errors
      onError: (error, stackTrace, type) {
        crashReporter.report(error, stackTrace);
      },
    ),
    lifecycles: [DebugLifecycle()],
  );
  runApp(MyApp());
}
```

**Equality priority**: full state uses local constructor `equals` → global
`ViewModelConfig.equals` → `identical()`. A selected value uses explicit
selector `equals` → global `ViewModelConfig.equals` → `==`. The global
comparator defaults to `null`. If it delegates to `==`, every state and selected
value type it receives must support the intended `==` semantics; state classes
should also implement matching `hashCode`.

---

## Testing

`ViewModelSpec` supports proxy overrides for testing. For scoped overrides,
`overrideWith` returns an idempotent restore callback, and `runWithOverride`
restores automatically after synchronous or asynchronous success/failure.
Nested and out-of-order restores are safe. Each `runWithOverride` invocation
uses its own async Zone, so overlapping asynchronous bodies do not observe one
another's scoped override selection. Normal key-based ViewModel instance
sharing still applies after factory selection. The older `setProxy` /
`clearProxy` pair remains available as a global legacy fallback:

```dart
final userSpec = ViewModelSpec<UserViewModel>(
  builder: () => UserViewModel(),
  key: 'user',
);

test('with mock', () {
  userSpec.setProxy(ViewModelSpec(
    builder: () => MockUserViewModel(),
    key: 'user',
  ));

  final binding = ViewModelBinding();
  final vm = binding.watch(userSpec);
  expect(vm, isA<MockUserViewModel>());

  binding.dispose();
  userSpec.clearProxy();
});
```

Parameterized specs (`ViewModelSpec.arg`, `.arg2`, etc.) also support `setProxy` / `clearProxy`.

```dart
await userSpec.runWithOverride(mockUserSpec, () async {
  final vm = binding.read(userSpec);
  expect(vm, isA<MockUserViewModel>());
}); // prior override is restored here, even if the body throws
```

Call `ViewModel.reset()` between isolated runtime tests when needed.
It force-disposes every cached instance (including `aliveForever` instances),
clears lifecycle/configuration and DevTools tracking state, and permits clean
re-initialization.

For widget-free testing, just use a plain `ViewModelBinding`:

```dart
test('interaction test', () {
  final binding = ViewModelBinding();
  final cart = binding.watch(cartSpec);
  final checkout = binding.watch(checkoutSpec);

  cart.addItem(Item('test'));
  expect(checkout.total, greaterThan(0));

  binding.dispose();
});
```

---

## Code Generation

The optional `view_model_generator` package auto-generates `ViewModelSpec` definitions from annotations:

```yaml
dev_dependencies:
  build_runner: ^2.0.0
  view_model_generator: ^latest
```

```dart
part 'counter_view_model.vm.dart';

@GenSpec
class CounterViewModel with ViewModel {
  int count = 0;
  void increment() => update(() => count++);
}
```

```bash
dart run build_runner build
```

Generated:
```dart
// counter_view_model.vm.dart
final counterViewModelSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

The generator supports ViewModels with up to 4 constructor parameters and produces the appropriate `ViewModelSpec.argN` variant.

---

## DevTools Extension

The package includes a Flutter DevTools extension for real-time ViewModel inspection. In debug mode, a `DevToolTracker` lifecycle observer is automatically registered, and a `DevToolsService` starts a VM service extension for communication with DevTools. Diagnostics expose the ordered active `owners`, the current `primaryOwner` used for nested dependency resolution, and primary-owner handoffs.

To enable, create `devtools_options.yaml` in your project root:

```yaml
description: This file stores settings for Dart & Flutter DevTools.
documentation: https://docs.flutter.dev/tools/devtools/extensions#configure-extension-enablement-states
extensions:
  - view_model: true
```

---


## view_model vs riverpod

Both are built on a central registry + dependency injection model, but they differ in API style, instance scope defaults, and lifecycle ergonomics. This comparison assumes common defaults (for example, a single root `ProviderScope`) and focuses on core state-management concerns: state modeling, reactive derivation, instance scope, and lifecycle. It does not treat `Mutations` / `Automatic retry` / `Offline persistence` as primary evaluation criteria.

### 1. Core Philosophy

- **Riverpod**: Everything is a global reactive node (Functional & Declarative).
  > Its core is building a global directed acyclic graph (DAG). State is a global singleton by default (mounted on `ProviderScope`), and it emphasizes pure functional derivation between states (Derived State). It strongly discourages binding state to a specific Widget instance.
- **view_model**: A classic component-level ViewModel (OOP & Lifecycle-bound).
  > Its core is reference-counting-based instance management. It injects capabilities into any class via mixins. By default, state is locally scoped (it lives and dies with the bound Widget lifecycle). It is closer to Android's ViewModel or traditional client-side MVVM.


### 2. Coding Style and Implementation

| Dimension | Riverpod 3.x | view_model 1.0.0 |
| :--- | :--- | :--- |
| **Class model** | Inheritance/codegen-based (`Notifier`, `AsyncNotifier`, `@riverpod`) | **Mixin-based** (`class X with ViewModel`) |
| **Strengths** | Strong provider composition and reactive derivation patterns | Low-intrusion style, multi-mixin flexibility, any Dart class can become a ViewModel |
| **watch/read location** | In `Consumer` widgets, `ref.watch(...)` is commonly used in `build`; it is also used inside provider/notifier `build`. For listeners outside `build` in widgets, `WidgetRef.listenManual(...)` is available | Can be exposed through a getter (`MyViewModel get vm => viewModelBinding.watch(...)`), not forced into `build` |

**view_model example (getter declaration):**

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  CounterViewModel get counterVM => viewModelBinding.watch(counterSpec);
  UserViewModel get userVM => viewModelBinding.watch(userSpec);

  @override
  Widget build(BuildContext context) {
    return Text('${counterVM.count}'); // reactive updates
  }
}
```

### 3. Instance Scope (Most Important Difference)

- **Riverpod**: instances are scoped by `ProviderContainer`. In most apps, a single root `ProviderScope` means one shared provider instance app-wide. Isolation is explicit via nested `ProviderScope`, overrides, or families.
- **view_model**: the default is one instance per resolved generic ViewModel type `T` per binding. Repeated same-`T` `watch/read` calls inside one `ViewModelBinding` reuse that instance; different pages/bindings are isolated. Use explicit keys for cross-binding sharing or multiple same-`T` instances inside one binding:

```dart
final globalAuthSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
  key: 'global-auth',
  aliveForever: true, // optional: retain after the last owner releases it
);
```
