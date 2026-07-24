---
name: view_model
description: Build or refactor Flutter functional modules and state management with the view_model package, including module-to-module dependency injection, ViewModel/ViewModelBinding mixins, ViewModelSpec sharing, watch/read semantics, lifecycle, pause-resume, testing, and code generation.
mintlify-proj: flutter-view-model
---

# view_model Skill

Use this skill when tasks involve Flutter `view_model` architecture, migration, bug fixing, performance tuning, or feature implementation.

## Source of truth

- Full reference (embedded in this skill):
  - `references/README_FULL_EN.md`
  - `references/README_FULL_ZH.md`
- Upstream source in repo:
  - `packages/view_model/README.md`
  - `packages/view_model/README_ZH.md`
- Skill-local examples: `examples/counter_example.dart`, `examples/state_view_model_example.dart`, `examples/sharing_example.dart`

If examples conflict with README, follow README.

## Full-reference loading policy

- For implementation/refactor/debug tasks, read `references/README_FULL_EN.md` first.
- For Chinese responses or terminology checks, also read `references/README_FULL_ZH.md`.
- For trivial requests (single API clarification), you may use this SKILL summary first, then open full reference only if uncertain.
- If embedded reference and upstream README diverge, treat upstream as latest truth and sync the embedded reference.
- Keep `references/README_FULL_*.md` as real files inside the skill package; do not replace them with symlinks to outside paths.

## Trigger phrases

Use this skill for requests like:
- "用 view_model 写/改状态管理"
- "watch/read 有什么区别"
- "ViewModelSpec 怎么做共享/单例"
- "每个功能模块都是 ViewModel / ViewModel 之间如何依赖注入"
- "StateViewModel / listenStateSelect / ValueWatcher"
- "生命周期、自动销毁、pause/resume"
- "`@GenSpec` 或 view_model_generator"

## Core model (must stay accurate)

- **Every functional module can be a ViewModel.** A ViewModel is not limited to
  page or UI state: a feature, service, repository, coordinator, or domain
  capability can all be modeled as `class X with ViewModel`.
- **ViewModel modules can inject each other.** Resolve module dependencies with
  non-caching `viewModelBinding.read/watch` getters. This forms a demand-driven
  module-to-module DI graph managed by binding-based reference counting.
- **Prefer managed instances over singletons.** Do not make a module static,
  global, keyed, or `aliveForever` by default. Let the first `read/watch`
  create it and let `ViewModelBinding` dispose it automatically.
- Architecture is type-keyed instance registry + binding-based reference counting.
- Two base mixins:
  - `with ViewModel`: managed instance (lifecycle + notify + DI access).
  - `with ViewModelBinding`: binding host (watch/read/listen/recycle APIs).
- Widget mixins are wrappers over `ViewModelBinding`:
  - `ViewModelStateMixin` (recommended default for widgets).
  - `ViewModelStatelessMixin` (lightweight, but has multi-mount caveat).

## Feature-module architecture

Treat `ViewModel` as the reusable unit of application functionality, rather
than as a class reserved for a screen. Keep each module independently
constructible through a `ViewModelSpec`, then compose larger modules by
injecting the smaller ViewModels they depend on:

```dart
class CheckoutViewModel with ViewModel {
  CartViewModel get cart => viewModelBinding.read(cartViewModelSpec);
  PricingViewModel get pricing =>
      viewModelBinding.read(pricingViewModelSpec);

  Future<void> submit() async {
    final cart = this.cart;
    final pricing = this.pricing;
    await pricing.validate(cart.items);
  }
}
```

- Prefer a getter over `late final`, a constructor-cached field, or `??=`.
  A getter re-resolves the dependency through the owner binding currently
  selected by `refHandler`—the first remaining owner, not necessarily the
  caller's root. Within one binding, the registry still returns the same
  managed instance.
- Use `read` when a module only needs to call another module.
- Use `watch` when dependency notifications must also update the parent
  binding. Do not put `listen` in a repeatedly evaluated getter because every
  evaluation can register another side-effect listener; register it explicitly
  in the binding owner instead.
- Keep dependency access inside `viewModelBinding` so each resolved module is
  owned and released by the root binding that resolved it.
- A ViewModel's identity is the resolved generic VM type `T` plus its effective
  `key`; the builder's runtime result type is not part of identity, and `tag`
  is only a grouping label. When factory `key()` returns `null`, the binding
  supplies a private default key, so the same `T` is reused within one binding
  and is isolated across bindings. Add a key to share across bindings,
  distinguish multiple instances of the same `T` in one binding, or provide
  stable keyed cached lookup. A key does not keep an instance alive.

### App composed from ViewModel modules (pseudo-code)

An app can be a graph of many small ViewModel modules. Specs below deliberately
have no `key` and no `aliveForever`; they are managed instances, not
singletons:

```dart
final sessionSpec = ViewModelSpec(builder: SessionViewModel.new);
final catalogSpec = ViewModelSpec(builder: CatalogViewModel.new);
final cartSpec = ViewModelSpec(builder: CartViewModel.new);
final paymentSpec = ViewModelSpec(builder: PaymentViewModel.new);
final checkoutSpec = ViewModelSpec(builder: CheckoutViewModel.new);
final appSpec = ViewModelSpec(builder: AppViewModel.new);

class SessionViewModel with ViewModel { /* login / token */ }

class CatalogViewModel with ViewModel { /* products / search */ }

class CartViewModel with ViewModel { /* cart state */ }

class PaymentViewModel with ViewModel { /* payment capability */ }

class CheckoutViewModel with ViewModel {
  SessionViewModel get session => viewModelBinding.read(sessionSpec);
  CartViewModel get cart => viewModelBinding.read(cartSpec);
  PaymentViewModel get payment => viewModelBinding.read(paymentSpec);

  Future<void> submit() async {
    final session = this.session;
    final cart = this.cart;
    final payment = this.payment;
    await payment.pay(user: session.user, items: cart.items);
  }
}

class AppViewModel with ViewModel {
  SessionViewModel get session => viewModelBinding.read(sessionSpec);
  CatalogViewModel get catalog => viewModelBinding.read(catalogSpec);
  CartViewModel get cart => viewModelBinding.read(cartSpec);
  CheckoutViewModel get checkout => viewModelBinding.read(checkoutSpec);
}

class _AppShellState extends State<AppShell> with ViewModelStateMixin {
  AppViewModel get app => viewModelBinding.watch(appSpec);

  @override
  Widget build(BuildContext context) => AppView(viewModel: app);
}
```

The getter declarations create nothing by themselves. `AppViewModel` is
created or reused when `_AppShellState.build` evaluates `app`; each child is
resolved only when its corresponding getter is evaluated. After every getter
above has been accessed, the conceptual dependency graph is:

```text
AppShell ViewModelBinding
└── AppViewModel
    ├── SessionViewModel
    ├── CatalogViewModel
    ├── CartViewModel
    └── CheckoutViewModel
        ├── SessionViewModel (same binding-managed instance)
        ├── CartViewModel (same binding-managed instance)
        └── PaymentViewModel
```

When `AppShell` is disposed, its binding releases every module that it actually
resolved. Any module with no remaining binding reference is disposed
automatically. This is binding ownership, not a parent-to-child ownership edge:
recycling a parent does not automatically recycle its children. Keep composite
or coordinator ViewModels unkeyed by default. If a leaf service must be shared,
put the explicit `key` on that leaf and make every root resolve it so every root
obtains its own binding reference.

### Shared-parent lifecycle boundary

A keyed parent ViewModel can be referenced by multiple root bindings, but its
nested dependencies are not transitively bound to every root that binds the
parent. `viewModelBinding` resolves through the first remaining owner binding
selected by `refHandler`, not necessarily the caller's root. A child resolved
by the shared parent belongs to that selected root unless the other roots
resolve the child themselves. When that root is disposed, the child may be
disposed while the keyed parent remains alive under another root.

Non-caching getters prevent the parent from retaining a disposed child: the
next access re-resolves through the next owner selected by `refHandler`. They
do not guarantee child state continuity; the child may be recreated. For
continuous shared state, prefer an unkeyed parent plus a keyed leaf resolved by
every root, or use a dedicated application-level binding owner. Use
`aliveForever` only when retention beyond binding lifetime is intentional;
explicit `recycle` is then responsible for early cleanup. Never cache a nested
ViewModel in `late final`, `final`, or `??=` on a cross-binding shared parent.

## Implementation workflow

1. Choose ViewModel style
- `with ViewModel`: mutable fields + `update`/`notifyListeners`.
- `StateViewModel<T>`: immutable state + `setState`, supports state diff/selective listeners.
- `ChangeNotifierViewModel`: only when extending `ChangeNotifier` behavior is required.

2. Define `ViewModelSpec`
- `ViewModelSpec<T>(builder: ...)` for no args.
- `ViewModelSpec.arg/arg2/arg3/arg4` for parameterized construction.
- Identity is resolved generic VM type `T` + effective `key`; `tag` and the
  builder's runtime result type do not participate in identity.
- When factory `key()` returns `null`, repeated access to the same `T` reuses
  one instance within a binding and remains isolated across bindings.
- Use `key` for cross-binding sharing or multiple same-`T` instances in one
  binding. It does not keep an instance alive.
- Use `tag` for grouped lookup.
- Use `aliveForever: true` only for intentional long-lived retention. It skips
  automatic disposal at zero binding references; `recycle` still force-disposes.

3. Integrate with host
- Widget page: `State<T> with ViewModelStateMixin`.
- Simple widget case: `StatelessWidget with ViewModelStatelessMixin`.
- No-custom-state option: `ViewModelBuilder<T>(spec, builder: ...)`.
- Cached-only builder option: `CachedViewModelBuilder<T>(shareKey: ... | tag: ..., builder: ...)`.
- Non-widget classes (bootstrap/service/test): `with ViewModelBinding` and call `dispose()` manually when done.

4. Choose access API correctly
- `watch(spec)`: create/get + bind + listen (reactive rebuild/`onUpdate`).
- `read(spec)`: create/get + bind, no ViewModel listener.
- Do not introduce direct cached lookup in normal application code. Prefer a
  stable spec and resolve it explicitly with `watch(spec)` or `read(spec)`.
- `listen/listenState/listenStateSelect`: side-effect listeners, auto-cleaned on binding dispose.
- `listenStateSelect` compares selected values with `==`; use
  `listenStateSelectWithEquals` for a custom strongly typed comparison.
- `recreate(vm, builder: ...)`: replace an instance while preserving active
  binding relationships; omit `builder` to reuse the original factory.
- `recycle(vm)`: force unbind all and dispose; next `watch/read` gets fresh instance.
- The built-in `ViewModelBinding` implements the optional recreate and custom
  selector-equality capabilities. A direct `ViewModelBindingInterface`
  implementation opts in via `ViewModelBindingRecreateCapability` and/or
  `ViewModelBindingStateSelectEqualsCapability`; otherwise the corresponding
  interface extension throws `UnsupportedError`.

5. Handle dependencies and sharing
- Model each independent functional capability as a ViewModel when it benefits
  from managed lifecycle, state notifications, dependency injection, or reuse.
- In a ViewModel, `viewModelBinding` is available via Zone from parent binding.
- ViewModel-to-ViewModel calls (`read/watch/listen`) are part of the same binding lifecycle chain.
- Resolve nested ViewModels through non-caching getters; do not retain them in
  `late final`, `final`, or `??=` fields.
- With `key() == null`: one instance per resolved generic VM type `T` per binding.
- With same `T` + same `key`: shared identity across bindings.
- Multiple instances of the same `T` in one binding need distinct keys.

6. Lifecycle and cleanup
- Lifecycle hooks: `onCreate`, `onBind`, `onUnbind`, `onDispose`.
- Prefer `addDispose(() { ... })` for subscriptions/controllers/stream cleanup.
- Auto-dispose occurs when handle `bindingIds` becomes empty and `aliveForever` is false.

7. Performance and visibility
- For route-based pause/resume, register:
  - `MaterialApp(navigatorObservers: [ViewModel.routeObserver])`
- Built-in pause providers: route cover, ticker mode, app lifecycle.
- Use `StateViewModelValueWatcher` for selector-level rebuilds; pair it with
  `read`, not `watch`, to avoid duplicate subscriptions and broad rebuilds.
- `ObservableValue` and `ObserverBuilder(1/2/3)` are deprecated compatibility
  APIs scheduled for removal in 2.0.0. Do not introduce new usages.
- Use Flutter's `ValueNotifier` + `ValueListenableBuilder` for widget-local
  values, or an explicit `StateViewModel` + `ViewModelSpec` for managed state.
  Add a `key` when cross-binding sharing, multiple same-type instances in one
  binding, or stable keyed cached lookup is required.

8. App-level setup
- Call `ViewModel.initialize(...)` once at app startup (subsequent calls are ignored).
- Configure `ViewModelConfig` when needed:
  - `isLoggingEnabled`
  - `equals` (state equality strategy)
  - `onError` (with `ErrorType.listener` / `ErrorType.lifecycle` / `ErrorType.dispose` / `ErrorType.pauseResume`)
- If using `equals: (a, b) => a == b`, ensure state classes implement `==` and `hashCode`.

9. Testing and mocking
- Prefer pure Dart unit tests with `ViewModelBinding()` (no `testWidgets` required for many cases).
- Never construct a ViewModel directly in a test body or `setUp`. Constructor
  calls belong inside a `ViewModelSpec`/factory builder; obtain the managed
  instance through the test binding's `read`/`watch` API.
- Do not retain a ViewModel in a `late`/`final` test field. Use a getter that
  resolves it through the test binding.
- Always `binding.dispose()` in teardown.
- For spec override: `spec.setProxy(...)` and `spec.clearProxy()`.

10. Code generation (optional)
- Annotate with `@GenSpec`, add `part '*.vm.dart'`, then run `dart run build_runner build`.
- Generator creates `xxxViewModelSpec` and supports up to 4 constructor args.

## Do/Don't checklist

Do:
- Default feature-module specs to no `key` and no `aliveForever`, allowing the
  binding to own creation, reuse, and disposal.
- Expose ViewModels through typed, non-caching getters that call
  `viewModelBinding.read/watch`.
- Keep `watch` for reactive UI, `read` for imperative actions.
- For field-level updates (`listenStateSelect`, `StateViewModelValueWatcher`,
  selector-based rebuilds), read the ViewModel with `read` and let the
  selector mechanism drive updates; avoid `watch` on the same ViewModel.
- Set explicit `key` whenever instance sharing is a requirement.
- Dispose non-widget bindings explicitly.
- Use `listenStateSelect` for side effects on selected state fields; use
  `listenStateSelectWithEquals` only when the selected value needs a custom
  equality rule.

Don't:
- Introduce a global singleton or service locator for ViewModel modules by
  default; compose modules through `viewModelBinding` instead.
- Claim `read` is "non-binding" (it still binds and affects lifecycle).
- Pair selector-level rebuild tools with `watch`; this usually causes broader
  rebuilds than intended.
- Cache a ViewModel dependency in `late final`, `final`, or `??=`; the active
  owner binding can change after recycle or shared-parent transfer.
- Introduce `ObservableValue` or `ObserverBuilder`; they are deprecated.
- Use cached APIs expecting auto-create behavior.
- Overuse `aliveForever` for page-scoped state.
- Forget `ViewModel.routeObserver` when relying on route pause behavior.

## Response pattern for implementation requests

When generating code for users:
- For app architecture, present features as collaborating ViewModel modules;
  compose them through `viewModelBinding` and default to managed, non-singleton
  specs without `key` or `aliveForever`.
- Prefer complete, runnable snippets with:
  - imports
  - ViewModel class
  - Spec declaration
  - widget/binding usage
  - disposal/setup notes
- State why `watch` or `read` was chosen.
- If introducing sharing, show explicit `key` and lifecycle implications.
