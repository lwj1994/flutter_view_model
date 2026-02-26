# view_model

[![pub package](https://img.shields.io/pub/v/view_model.svg)](https://pub.dev/packages/view_model)

[简体中文](./README_ZH.md)

A Flutter state management library built on a type-keyed instance registry with automatic reference-counted lifecycle.

```yaml
dependencies:
  view_model: ^1.0.0
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
  - [Cached Access](#cached-access)
  - [listen / listenState / listenStateSelect](#listen--listenstate--listenstateselect)
  - [recycle](#recycle)
- [Instance Sharing](#instance-sharing)
  - [key-based Sharing](#key-based-sharing)
  - [tag-based Lookup](#tag-based-lookup)
  - [aliveForever Singletons](#aliveforever-singletons)
  - [Static Global Access](#static-global-access)
- [ViewModelBinding in Any Class](#viewmodelbinding-in-any-class)
- [ViewModel-to-ViewModel Dependencies](#viewmodel-to-viewmodel-dependencies)
- [Fine-Grained Reactivity](#fine-grained-reactivity)
  - [StateViewModelValueWatcher](#stateviewmodelvaluewatcher)
  - [ObservableValue & ObserverBuilder](#observablevalue--observerbuilder)
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
  late final vm = viewModelBinding.watch(counterSpec);

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

State equality is checked by `identical()` by default. You can override this globally via `ViewModelConfig.equals` so that, for example, `==` is used instead (see [Configuration](#configuration)).

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

Internally, `ViewModelSpec` extends `ViewModelFactory<T>`, which defines:
- `build()` — creates the instance
- `key()` — cache key (same key = same instance)
- `tag()` — logical grouping label
- `aliveForever()` — whether to skip auto-disposal

---

## Widget Integration

### ViewModelStateMixin

The primary way to use ViewModels in widgets. Mix it into `State<T>`:

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  late final vm = viewModelBinding.watch(mySpec);

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
  late final vm = viewModelBinding.watch(mySpec);
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

### Cached Access

These methods look up an already-created instance by `key` or `tag`. They never create new instances. Like `watch`/`read`, the `watch` variants bind + listen, while the `read` variants bind only.

```dart
// Throws if not found
final vm = viewModelBinding.watchCached<MyVM>(key: 'abc');
final vm = viewModelBinding.readCached<MyVM>(tag: 'dashboard');

// Returns null if not found
final vm = viewModelBinding.maybeWatchCached<MyVM>(key: 'abc');
final vm = viewModelBinding.maybeReadCached<MyVM>(tag: 'dashboard');
```

Batch retrieval by tag:
```dart
List<MyVM> vms = viewModelBinding.watchCachesByTag<MyVM>('group-a');
List<MyVM> vms = viewModelBinding.readCachesByTag<MyVM>('group-a');
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

// StateViewModel: selected property only — fires only when selector output differs
viewModelBinding.listenStateSelect(
  userSpec,
  selector: (UserState s) => s.name,
  onChanged: (String? prevName, String currName) {
    print('name changed to $currName');
  },
);
```

### recycle

Force-disposes a ViewModel by calling `unbindAll()` on its handle (removes all bindingIds, triggering disposal). The next `watch`/`read` call with the same spec will create a fresh instance.

```dart
viewModelBinding.recycle(vm);
// vm is now disposed
final freshVm = viewModelBinding.watch(spec); // new instance
```

---

## Instance Sharing

### key-based Sharing

When a `ViewModelSpec` has a `key`, any binding that calls `watch`/`read` with the same key gets the **same instance**. Each binding adds its own `bindingId` to the handle — the instance stays alive until all bindings unbind.

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

Without a `key`, each binding creates a new, independent instance scoped to that binding alone.

### tag-based Lookup

`tag` is a grouping label. Multiple instances can share the same tag. Use `watchCached`/`readCached` with `tag:` to find the most recently created instance with that tag:

```dart
final spec = ViewModelSpec<ItemVM>(
  builder: () => ItemVM(),
  tag: 'active-items',
);
```

### aliveForever Singletons

Set `aliveForever: true` to prevent auto-disposal. When the handle's `bindingIds` becomes empty, `_recycle()` checks this flag and skips disposal. The instance lives until the process ends:

```dart
final authSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
  key: 'auth',
  aliveForever: true,
);
```

### Static Global Access

Read any cached ViewModel from anywhere (no binding context needed). These are pure lookups — they don't bind or create instances:

```dart
final auth = ViewModel.readCached<AuthViewModel>(key: 'auth');
final auth = ViewModel.maybeReadCached<AuthViewModel>(key: 'auth'); // null-safe
```

---

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

Inside a ViewModel, `viewModelBinding` is available and resolves via a Dart Zone to the parent binding that created it. This means ViewModel-to-ViewModel access goes through the same binding system — sub-ViewModels are bound to the same root binding, and their lifecycles are managed together.

```dart
class OrderViewModel with ViewModel {
  late final cart = viewModelBinding.read(cartSpec);
  late final user = viewModelBinding.read(userSpec);

  double get total => cart.items.fold(0, (sum, i) => sum + i.price);
}
```

Reactive dependencies with `watch` (when the dependency notifies, the parent binding's `onUpdate` fires):

```dart
class DashboardViewModel with ViewModel {
  DashboardViewModel() {
    viewModelBinding.watch(authSpec);
  }
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

When the root widget's binding disposes, it unbinds from all handles — including those created transitively by ViewModel-to-ViewModel dependencies. If no other binding holds those handles, they are disposed as well.

---

## Fine-Grained Reactivity

### StateViewModelValueWatcher

Only rebuilds when the selected properties of a `StateViewModel` change:

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  // Use read — the ValueWatcher handles its own subscriptions internally
  late final vm = viewModelBinding.read(userSpec);

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

Internally, each selector is wrapped into a `listenStateSelect` call on the ViewModel. The widget only rebuilds when at least one selector's output differs from its previous value (compared using `ViewModelConfig.equals` or `==` by default).

### ObservableValue & ObserverBuilder

A lightweight reactive value that doesn't require defining a ViewModel class. Under the hood, each `ObservableValue` creates a hidden `StateViewModel` instance in the registry, keyed by `shareKey`:

```dart
// Declare (can be top-level)
final isDarkMode = ObservableValue<bool>(false, shareKey: 'theme-dark');

// Update from anywhere
isDarkMode.value = true;

// Observe in UI
ObserverBuilder<bool>(
  observable: isDarkMode,
  builder: (dark) => Icon(dark ? Icons.dark_mode : Icons.light_mode),
)
```

Multi-value variants:

```dart
ObserverBuilder2<int, String>(
  observable1: counter,
  observable2: label,
  builder: (count, label) => Text('$label: $count'),
)

ObserverBuilder3<int, String, bool>(
  observable1: counter,
  observable2: label,
  observable3: isActive,
  builder: (count, label, active) => /* ... */,
)
```

If two `ObservableValue` instances share the same `shareKey`, they point to the same underlying StateViewModel — this is how you share reactive values across unrelated parts of the widget tree.

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
   onUnbind(arg, bindingId) ← a ViewModelBinding unbinds (dispose or recycle)
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
  late final StreamSubscription _sub;

  StreamViewModel() {
    _sub = someStream.listen((_) => notifyListeners());
    addDispose(() => _sub.cancel());
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

      // Custom state equality (default: identical())
      // Used by StateViewModel.setState and listenStateSelect
      equals: (a, b) => a == b,

      // Global error handler for listener errors
      onListenerError: (error, stackTrace, context) {
        // context is 'notifyListeners' or 'stateListener'
        crashReporter.report(error, stackTrace);
      },

      // Global error handler for disposal errors
      onDisposeError: (error, stackTrace) {
        debugPrint('Disposal error: $error');
      },
    ),
    lifecycles: [DebugLifecycle()],
  );
  runApp(MyApp());
}
```

**State equality note**: by default `StateViewModel.setState` uses `identical()` to decide whether to skip the update. This means creating a new object with the same field values will still trigger notification. If you configure `equals: (a, b) => a == b`, you need to implement `==` and `hashCode` on your state classes.

---

## Testing

`ViewModelSpec` supports proxy overrides for testing. Call `setProxy` to replace the builder (and optionally key/tag), and `clearProxy` to restore:

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

The package includes a Flutter DevTools extension for real-time ViewModel inspection. In debug mode, a `DevToolTracker` lifecycle observer is automatically registered, and a `DevToolsService` starts a VM service extension for communication with DevTools.

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
| **watch/read location** | In `Consumer` widgets, `ref.watch(...)` is commonly used in `build`; it is also used inside provider/notifier `build`. For listeners outside `build` in widgets, `WidgetRef.listenManual(...)` is available | Can be declared as class fields (`late final vm = viewModelBinding.watch(...)`), not forced into `build` |

**view_model example (field declaration):**

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  late final counterVM = viewModelBinding.watch(counterSpec); // initialized once
  late final userVM = viewModelBinding.watch(userSpec);

  @override
  Widget build(BuildContext context) {
    return Text('${counterVM.count}'); // reactive updates
  }
}
```

### 3. Instance Scope (Most Important Difference)

- **Riverpod**: instances are scoped by `ProviderContainer`. In most apps, a single root `ProviderScope` means one shared provider instance app-wide. Isolation is explicit via nested `ProviderScope`, overrides, or families.
- **view_model**: default is **per-binding singleton**. Repeated `watch/read` calls inside the same `ViewModelBinding` share one instance; different pages/bindings are isolated by default. Global sharing is explicit via key:

```dart
final globalAuthSpec = ViewModelSpec<AuthViewModel>(
  builder: () => AuthViewModel(),
  key: 'global-auth',
  aliveForever: true, // optional: keep alive
);
```
