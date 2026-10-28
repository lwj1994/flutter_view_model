# view_model_lint rules

Good and bad examples for every diagnostic reported by `view_model_lint`.
Enable the plugin as described in the [README](README.md). Ten rules are
warnings enabled by default; `view_model_cached_lookup` is an opt-in info.
Rules with a quick fix offer it from the IDE lightbulb, and
`view_model_lint_fix` applies them across a package; `dart fix` cannot apply
plugin fixes. See [Quick fixes](README.md#quick-fixes).

| Rule | Default | Catches |
| --- | --- | --- |
| [`view_model_dependency_cycle`](#view_model_dependency_cycle) | warning | ViewModels that resolve each other |
| [`view_model_cached_instance`](#view_model_cached_instance) | warning | A resolved ViewModel kept in a field |
| [`view_model_alive_forever_key`](#view_model_alive_forever_key) | warning | `aliveForever` without a key |
| [`view_model_unmanaged_construction`](#view_model_unmanaged_construction) | warning | A ViewModel constructed outside a builder |
| [`view_model_listen_in_build`](#view_model_listen_in_build) | warning | A listener registered on every build |
| [`view_model_instance_handoff`](#view_model_instance_handoff) | warning | A ViewModel passed through a constructor |
| [`view_model_identity_collision`](#view_model_identity_collision) | warning | Unkeyed resolutions that share one instance |
| [`view_model_selector_with_watch`](#view_model_selector_with_watch) | warning | A selector widget fed by `watch` |
| [`view_model_undisposed_binding`](#view_model_undisposed_binding) | warning | A `ViewModelBinding` that is never disposed |
| [`view_model_temporary_spec`](#view_model_temporary_spec) | warning | A spec that is not a top-level or static variable |
| [`view_model_cached_lookup`](#view_model_cached_lookup) | off (info) | A cached query used instead of a spec |

## Shared declarations

The examples below use these declarations:

```dart
import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

class CounterState {
  const CounterState(this.count);
  final int count;
}

class CounterViewModel extends StateViewModel<CounterState> {
  CounterViewModel() : super(state: const CounterState(0));

  void increment() => setState(CounterState(state.count + 1));
}

class UserViewModel with ViewModel {
  UserViewModel(this.userId);
  final String userId;
}

final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
);

final userSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: UserViewModel.new,
  key: (userId) => ('user', userId),
);
```

A `State<CounterPage>` in an example belongs to an ordinary `StatefulWidget`
named `CounterPage`.

## `view_model_dependency_cycle`

Two or more ViewModels resolve each other through their own
`viewModelBinding`. Resolving any of them can recurse until the runtime cycle
check throws.

**Bad**

```dart
final sessionSpec = ViewModelSpec<SessionViewModel>(
  builder: SessionViewModel.new,
);
final cartSpec = ViewModelSpec<CartViewModel>(builder: CartViewModel.new);

class SessionViewModel with ViewModel {
  CartViewModel get cart => viewModelBinding.read(cartSpec);
}

class CartViewModel with ViewModel {
  SessionViewModel get session => viewModelBinding.read(sessionSpec);
}
```

**Good**

Keep dependencies pointing one way. Move state that both sides need into the
lower-level module.

```dart
final sessionSpec = ViewModelSpec<SessionViewModel>(
  builder: SessionViewModel.new,
);
final cartSpec = ViewModelSpec<CartViewModel>(builder: CartViewModel.new);

class SessionViewModel with ViewModel {
  String? userId;
}

class CartViewModel with ViewModel {
  SessionViewModel get session => viewModelBinding.read(sessionSpec);
}
```

The rule compares types. If keys make the instances distinct on purpose,
suppress the warning with a reason.

## `view_model_cached_instance`

The result of `read`, `watch`, their host extensions, or a single cached query
is stored in a field or top-level variable. After `recycle` or disposal, the
field still points at the old, disposed generation.

Quick fix: a `final` or `late final` field, or a top-level variable, becomes a getter.

**Bad**

```dart
class CheckoutViewModel with ViewModel {
  late final CounterViewModel counter = viewModelBinding.read(counterSpec);
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel? counter;

  @override
  void initState() {
    super.initState();
    counter = viewModelBinding.watch(counterSpec);
  }

  @override
  Widget build(BuildContext context) => Text('${counter?.state.count}');
}
```

**Good**

Resolve in a getter on every access. A local variable inside one method call
is fine.

```dart
class CheckoutViewModel with ViewModel {
  CounterViewModel get counter => viewModelBinding.read(counterSpec);

  void submit() {
    final counter = this.counter;
    counter.increment();
  }
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counter => viewModelBinding.watch(counterSpec);

  @override
  Widget build(BuildContext context) => Text('${counter.state.count}');
}
```

## `view_model_alive_forever_key`

`aliveForever: true` keeps an instance after its last owner leaves. Without a
key, nothing can find that instance again, and the runtime rejects it before
the builder runs.

Quick fix: adds `key: 'auth'` for `authSpec`, or `(arg) => ('userCache', arg)`
for a parameterized spec.

**Bad**

```dart
class AuthViewModel with ViewModel {}

final authSpec = ViewModelSpec<AuthViewModel>(
  builder: AuthViewModel.new,
  aliveForever: true,
);

final userCacheSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: UserViewModel.new,
  aliveForever: (_) => true,
);
```

**Good**

```dart
class AuthViewModel with ViewModel {}

final authSpec = ViewModelSpec<AuthViewModel>(
  builder: AuthViewModel.new,
  key: 'auth',
  aliveForever: true,
);

final userCacheSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: UserViewModel.new,
  key: (userId) => ('user', userId),
  aliveForever: (_) => true,
);
```

To share one instance between pages, a key alone is usually enough. The
instance is disposed after the last page leaves, so `aliveForever` is not
needed.

## `view_model_unmanaged_construction`

A ViewModel is constructed outside a spec builder, `ViewModelFactory.build`,
or a `@GenSpec` factory named `spec`. No binding owns it, so it never gets
lifecycle callbacks or automatic disposal.

**Bad**

```dart
void main() {
  final counter = CounterViewModel();
  counter.increment();
}
```

**Good**

```dart
void main() {
  final binding = ViewModelBinding();
  binding.read(counterSpec).increment();
  binding.dispose();
}
```

Construct the ViewModel in the spec builder, as `counterSpec` does, and
resolve the spec through a binding. This also applies in tests.

## `view_model_listen_in_build`

`listen`, `listenState`, or `listenStateSelect` runs in `build`,
`didUpdateWidget`, `didChangeDependencies`, a binding's `onUpdate`, or a
getter. Bindings do not deduplicate listeners, so each rebuild or access adds
another one, and the callback runs once per registration.

**Bad**

```dart
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  @override
  Widget build(BuildContext context) {
    viewModelBinding.listenState<CounterViewModel, CounterState>(
      counterSpec,
      onChanged: (previous, state) => debugPrint('count ${state.count}'),
    );
    return Text('${viewModelBinding.watch(counterSpec).state.count}');
  }
}

class BadgeViewModel with ViewModel {
  CounterViewModel get counter {
    viewModelBinding.listen(counterSpec, onChanged: notifyListeners);
    return viewModelBinding.read(counterSpec);
  }
}
```

**Good**

Register once, in `initState` for a widget or in `onCreate` for a ViewModel.
The binding removes the listener when it is disposed.

```dart
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  @override
  void initState() {
    super.initState();
    viewModelBinding.listenState<CounterViewModel, CounterState>(
      counterSpec,
      onChanged: (previous, state) => debugPrint('count ${state.count}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text('${viewModelBinding.watch(counterSpec).state.count}');
  }
}

class BadgeViewModel with ViewModel {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    viewModelBinding.listen(counterSpec, onChanged: notifyListeners);
  }

  CounterViewModel get counter => viewModelBinding.read(counterSpec);
}
```

A listener registered inside a callback, such as `onPressed`, is not reported.
It still adds a listener each time the callback runs.

## `view_model_instance_handoff`

A constructor parameter has a ViewModel type, so a resolved instance moves to
an owner that never bound it. The receiver can keep a disposed or recycled
generation alive.

**Bad**

```dart
class CounterLabel extends StatelessWidget {
  const CounterLabel({super.key, required this.counter});
  final CounterViewModel counter;

  @override
  Widget build(BuildContext context) => Text('${counter.state.count}');
}

class ReportViewModel with ViewModel {
  ReportViewModel(this.counter);
  final CounterViewModel counter;
}
```

**Good**

Pass plain data, or let the receiver resolve the same spec through its own
binding.

```dart
class CounterLabel extends StatelessWidget {
  const CounterLabel({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Text('$count');
}

class CounterBadge extends StatelessWidget with ViewModelStatelessMixin {
  CounterBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('${viewModelBinding.watch(counterSpec).state.count}');
  }
}

class ReportViewModel with ViewModel {
  CounterViewModel get counter => viewModelBinding.read(counterSpec);
}
```

## `view_model_identity_collision`

Instance identity is the ViewModel type plus the key. Within one binding,
every unkeyed resolution of a type returns the first instance created. Two
different specs, or one parameterized spec called with different arguments,
silently share that instance.

**Bad**

```dart
class ItemViewModel with ViewModel {
  ItemViewModel(this.id);
  final String id;
}

final itemSpec = ViewModelSpec.arg<ItemViewModel, String>(
  builder: ItemViewModel.new,
);

final firstCounterSpec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
);
final secondCounterSpec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
);

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get first => viewModelBinding.watch(firstCounterSpec);
  CounterViewModel get second => viewModelBinding.watch(secondCounterSpec);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${first.state.count} ${second.state.count}'),
        for (final id in ['a', 'b', 'c'])
          Text(viewModelBinding.watch(itemSpec(id)).id),
      ],
    );
  }
}
```

Every row shows `a`, and `second` is the same object as `first`.

**Good**

Give each instance a key. For a parameterized spec, derive the key from the
argument.

```dart
class ItemViewModel with ViewModel {
  ItemViewModel(this.id);
  final String id;
}

final itemSpec = ViewModelSpec.arg<ItemViewModel, String>(
  builder: ItemViewModel.new,
  key: (id) => ('item', id),
);

final firstCounterSpec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
  key: 'first-counter',
);
final secondCounterSpec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
  key: 'second-counter',
);

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get first => viewModelBinding.watch(firstCounterSpec);
  CounterViewModel get second => viewModelBinding.watch(secondCounterSpec);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${first.state.count} ${second.state.count}'),
        for (final id in ['a', 'b', 'c'])
          Text(viewModelBinding.watch(itemSpec(id)).id),
      ],
    );
  }
}
```

Resolving the same unkeyed spec with the same argument in several places is
fine, because one instance per binding is the intent.

## `view_model_selector_with_watch`

`StateViewModelValueWatcher` rebuilds only when a selected value changes. If
its ViewModel comes from `watch`, every notification also rebuilds the whole
owner, which defeats the selectors.

Quick fix: a direct `watch` call becomes `read`.

**Bad**

```dart
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counter => viewModelBinding.watch(counterSpec);

  @override
  Widget build(BuildContext context) {
    return StateViewModelValueWatcher<CounterState>(
      viewModel: counter,
      selectors: [(state) => state.count],
      builder: (state) => Text('${state.count}'),
    );
  }
}
```

**Good**

```dart
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counter => viewModelBinding.read(counterSpec);

  @override
  Widget build(BuildContext context) {
    return StateViewModelValueWatcher<CounterState>(
      viewModel: counter,
      selectors: [(state) => state.count],
      builder: (state) => Text('${state.count}'),
    );
  }
}
```

## `view_model_undisposed_binding`

A `ViewModelBinding` you create keeps every ViewModel it resolved bound until
`dispose()` runs. Without that call, those instances are never disposed. In
tests, they also leak into later tests, because the registry is
process-global.

**Bad**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('increments', () {
    final binding = ViewModelBinding();
    binding.read(counterSpec).increment();
    expect(binding.read(counterSpec).state.count, 1);
  });

  test('temporary binding', () {
    ViewModelBinding().read(counterSpec).increment();
  });
}
```

**Good**

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ViewModelBinding binding;
  setUp(() => binding = ViewModelBinding());
  tearDown(() => binding.dispose());

  test('increments', () {
    binding.read(counterSpec).increment();
    expect(binding.read(counterSpec).state.count, 1);
  });

  test('local binding', () {
    final local = ViewModelBinding();
    addTearDown(local.dispose);
    local.read(counterSpec).increment();
  });
}

class AppBootstrap {
  final _binding = ViewModelBinding();

  CounterViewModel get counter => _binding.read(counterSpec);

  void dispose() => _binding.dispose();
}
```

A binding passed to another object, returned, or assigned elsewhere counts as
handed over and is not reported. If a wrapper method such as `close()` calls
`dispose()` for you, suppress the warning with a reason.

## `view_model_temporary_spec`

A spec, including a custom `ViewModelFactory`, must be created exactly once:
in the initializer of a top-level variable or a static field. A spec in a
local variable, an instance field, a function result, or inline at a call is
rebuilt on every evaluation. A test can no longer replace it with `setProxy`.

Quick fixes: make an instance-field spec `static`, or move a spec that captures
nothing from its scope to a private top-level `final`.

**Bad**

```dart
class TodoViewModel with ViewModel {}

class TodoViewModelFactory with ViewModelFactory<TodoViewModel> {
  @override
  TodoViewModel build() => TodoViewModel();
}

ViewModelSpec<UserViewModel> userSpecFor(String userId) {
  return ViewModelSpec(builder: () => UserViewModel(userId), key: userId);
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  final pageSpec = ViewModelSpec<CounterViewModel>(
    builder: CounterViewModel.new,
  );

  CounterViewModel get counter => viewModelBinding.watch(
    ViewModelSpec(builder: CounterViewModel.new),
  );

  TodoViewModel get todo =>
      watchViewModel(factory: TodoViewModelFactory());

  @override
  Widget build(BuildContext context) {
    final local = ViewModelSpec(builder: CounterViewModel.new);
    return Text(
      '${counter.state.count} ${todo.hashCode} '
      '${viewModelBinding.read(local).state.count} ${pageSpec.hashCode}',
    );
  }
}
```

**Good**

```dart
class TodoViewModel with ViewModel {}

class TodoViewModelFactory with ViewModelFactory<TodoViewModel> {
  @override
  TodoViewModel build() => TodoViewModel();
}

final todoViewModelFactory = TodoViewModelFactory();

class Box<T> with ViewModel {}

// Dart has no generic variables, so a generic ViewModel uses a generic
// function that only returns the spec. @GenSpec generates this form.
ViewModelSpec<Box<T>> boxSpec<T>() => ViewModelSpec<Box<T>>(builder: Box<T>.new);

class Specs {
  static final counter = ViewModelSpec<CounterViewModel>(
    builder: CounterViewModel.new,
  );
}

class FakeCounterViewModel extends CounterViewModel {}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counter => viewModelBinding.watch(Specs.counter);
  UserViewModel get user => viewModelBinding.read(userSpec('42'));
  TodoViewModel get todo => watchViewModel(factory: todoViewModelFactory);
  Box<int> get box => viewModelBinding.read(boxSpec<int>());

  @override
  Widget build(BuildContext context) {
    return Text('${counter.state.count} ${user.userId} ${todo.hashCode}');
  }
}

void overrideForTest() {
  // A replacement passed straight to setProxy is reached only through
  // the stable spec it overrides.
  counterSpec.setProxy(ViewModelSpec(builder: FakeCounterViewModel.new));
  counterSpec.clearProxy();
}
```

Calling a parameterized spec, as in `userSpec('42')`, is the intended use and
is not reported.

## `view_model_cached_lookup`

Opt-in info. A cached query such as `readCached`, `watchCached`,
`maybeReadCached`, or `readCachesByTag` only finds an instance that another
owner already created. The result depends on creation order, and a miss throws
or returns `null`. Enable the rule in `analysis_options.yaml`:

```yaml
plugins:
  view_model_lint:
    version: ^1.3.1
    diagnostics:
      view_model_cached_lookup: true
```

**Bad**

```dart
class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counter =>
      viewModelBinding.watchCached<CounterViewModel>(key: 'shared-counter');

  @override
  Widget build(BuildContext context) => Text('${counter.state.count}');
}
```

**Good**

Share through a keyed spec. Every owner that resolves it gets the same
instance, and whichever comes first creates it.

```dart
final sharedCounterSpec = ViewModelSpec<CounterViewModel>(
  builder: CounterViewModel.new,
  key: 'shared-counter',
);

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counter => viewModelBinding.watch(sharedCounterSpec);

  @override
  Widget build(BuildContext context) => Text('${counter.state.count}');
}
```

## Suppressing a diagnostic

Fix the ownership or spec problem first. For an intentional exception, add a
local ignore with the reason:

```text
// ignore: view_model_lint/view_model_cached_instance -- kept for the app lifetime
```

To turn a rule off for a whole package, set it to `false` under the plugin's
`diagnostics` map.
