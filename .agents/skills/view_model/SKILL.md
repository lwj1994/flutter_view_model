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
- Architecture example: `examples/instagram_architecture/README.md` — a
  multi-file Instagram-style app composed from API, repository, user, feed,
  post-detail, comment, and startup-coordinator ViewModels.

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

## Primary resolution rule (must follow)

- **`watch(spec)` and `read(spec)` are the recommended primary entry points.**
  Use a stable `ViewModelSpec` for normal widget access, plain binding hosts,
  tests, and ViewModel-to-ViewModel dependencies.
- Choose `watch(spec)` when ViewModel notifications should update the owner;
  choose `read(spec)` for lifecycle-bound access without listening to the
  ViewModel's own `notifyListeners()`.
- Cached APIs are not an alternative dependency-resolution style. They are
  advanced, lookup-only escape hatches for intentionally querying an instance
  already created by another owner. Do not suggest them by default.

## Instance identity: choose keys deliberately

**Instance identity is the resolved generic VM type `T` plus the effective
`key`.** A spec declares construction; the spec object, constructor arguments,
builder's runtime result type, and `tag` do not independently define identity.
On a cache hit, the existing instance is returned without running the builder.

| Resolution pattern | Instance behavior |
| --- | --- |
| Same `T`, same binding, no explicit key | Reuses one instance, even with different specs or arguments. |
| Same `T`, different bindings, no explicit key | Separate instances, including dependencies of different parent generations. |
| Same `T`, equal explicit keys | Shares one instance across bindings while it remains alive. |
| Different `T`, equal explicit keys | Separate instances. |

Keep ordinary modules unkeyed when one instance per binding is intended. Set a
key when owners must share an instance or when one binding needs distinct
instances of the same `T`. For argument-based specs, encode the arguments that
identify the entity in the key:

```dart
final userSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: UserViewModel.new,
  key: (userId) => ('user', userId),
);
```

Here `userSpec('A')` and `userSpec('B')` resolve different instances. Without
the key callback, both resolve the first-created `UserViewModel` in the same
binding. New arguments with an unchanged key do not reconfigure that instance.
Calling the same unkeyed spec from two different parents does not share a child.

A key controls identity, not retention. Shared instances still auto-dispose
after their final owner leaves. Use `aliveForever: true` only when the instance
must survive with no owners, and always pair it with an explicit key.

## Core model (must stay accurate)

- **Primary resolution uses `watch(spec)` / `read(spec)`.** Generated examples,
  architecture advice, and migrations should preserve a spec instead of
  reaching into the cache by key/tag.
- **Every functional module can be a ViewModel.** A ViewModel is not limited to
  page or UI state: a feature, service, repository, coordinator, or domain
  capability can all be modeled as `class X with ViewModel`.
- **ViewModel modules can inject each other.** Resolve module dependencies with
  non-caching `viewModelBinding.read/watch` getters. This forms a demand-driven
  module-to-module DI graph managed by binding-based reference counting.
- **Never pass resolved ViewModel instances between lifecycle owners.** A raw
  reference does not establish binding ownership and can escape the lifetime of
  the binding that resolved it. Give each owner a stable spec and resolve it
  through that owner's `viewModelBinding`; pass plain data, IDs, value objects,
  or narrow callbacks across non-ViewModel boundaries instead.
- **Prefer managed instances over singletons.** Do not make a module static,
  global, keyed, or `aliveForever` by default. Let the first `read/watch`
  create it and let `ViewModelBinding` dispose it automatically.
- Architecture is type-keyed instance registry + binding-based reference counting.
- DevTools models initialized/observed root and dependency bindings as explicit
  lifecycle nodes. A parent generation's nested scope is a virtual binding, so
  diagnostics should preserve the chain
  `parent VM → virtual binding → child VM` with typed ownership relationships.
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
  Each parent object generation owns a stable internal dependency binding, so
  unkeyed child identity does not switch when root owners change. A getter still
  allows a new generation to be resolved after explicit recycle or an
  asynchronous lifecycle race.
- Use `read` when a module only needs to call another module.
- Use `watch` when dependency notifications must also notify the parent
  ViewModel. Synchronous propagation is transaction-based and deduplicated per
  binding, including diamond graphs. Do not put `listen` in a repeatedly
  evaluated getter because every
  evaluation can register another side-effect listener; register it explicitly
  in the binding owner instead.
- Keep dependency access inside `viewModelBinding` so each resolved module is
  owned by the parent generation. The parent's current root bindings are also
  mirrored to already-resolved children in real time.
- Apply the instance identity rules above when composing modules: each parent
  generation owns a distinct dependency binding, so shared children need keys.

### App composed from ViewModel modules (pseudo-code)

An app can be a graph of many small ViewModel modules. App and Checkout both
need the same session and cart, so those two specs have explicit keys. The
other specs remain unkeyed. All specs use the default automatic disposal:

```dart
final sessionSpec = ViewModelSpec(
  builder: SessionViewModel.new,
  key: 'session',
);
final catalogSpec = ViewModelSpec(builder: CatalogViewModel.new);
final cartSpec = ViewModelSpec(
  builder: CartViewModel.new,
  key: 'cart',
);
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
  // AppShell displays session state, so session notifications must bubble up.
  SessionViewModel get session => viewModelBinding.watch(sessionSpec);
  CatalogViewModel get catalog => viewModelBinding.read(catalogSpec);
  CartViewModel get cart => viewModelBinding.read(cartSpec);
  CheckoutViewModel get checkout => viewModelBinding.read(checkoutSpec);
}

class _AppShellState extends State<AppShell> with ViewModelStateMixin {
  AppViewModel get app => viewModelBinding.watch(appSpec);

  @override
  Widget build(BuildContext context) {
    final app = this.app;
    return AppView(
      isSignedIn: app.session.isSignedIn,
      onCheckout: app.checkout.submit,
    );
  }
}
```

The explicit session/cart keys make App and Checkout resolve the same
instances; using the same spec variable alone would not do so. The getter
declarations create nothing by themselves. `AppViewModel` is
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
        ├── SessionViewModel (same keyed instance as App.session)
        ├── CartViewModel (same keyed instance as App.cart)
        └── PaymentViewModel
```

When `AppShell` is disposed, `AppViewModel` loses its final root owner and is
disposed. Its generation-owned dependency binding then releases every resolved
child edge; children without another direct or parent path are disposed
automatically. Keep composite or coordinator ViewModels unkeyed by default. If
a leaf service must be shared across independent parent generations, put an
explicit `key` on that leaf.

### Shared-parent lifecycle boundary

A keyed parent ViewModel can be referenced by multiple root bindings. Its
generation-owned dependency binding keeps every resolved child alive for at
least the parent's lifetime and mirrors root additions/removals to each child.
If A leaves while B still owns the parent, an unkeyed child keeps the same
identity and state while its propagated A source is removed.

Ownership is source-aware. A root may own the same keyed child directly and
through multiple parents; releasing one path cannot remove another. Use an
explicit key when a leaf must be shared across independent parent generations.
Every `aliveForever` instance must also use an explicit key, at both root and
nested resolution sites, so its retained cache has a globally reachable
identity. Never cache a nested ViewModel in `late final`, `final`, or `??=`;
explicit recycle and asynchronous disposal still require getter-based
re-resolution.

### Local scope: sharing one instance across pages

A common case is for page A to display data and page B to edit it. Page A must
see B's changes when B closes; if both pages are visible, A should react to the
changes immediately. Prefer the same spec with an explicit key and default
auto-disposal. Do not set `aliveForever: true` merely to share across pages:

```dart
class DraftViewModel with ViewModel {
  DraftViewModel(this.documentId);

  final String documentId;
  String title = '';

  void updateTitle(String value) => update(() => title = value);
}

final draftViewModelSpec = ViewModelSpec.arg<DraftViewModel, String>(
  builder: DraftViewModel.new,
  key: (documentId) => ('draft', documentId),
);

class _PageAState extends State<PageA> with ViewModelStateMixin<PageA> {
  DraftViewModel get draft =>
      viewModelBinding.watch(draftViewModelSpec(widget.documentId));

  @override
  Widget build(BuildContext context) => Text(draft.title);
}

class _PageBState extends State<PageB> with ViewModelStateMixin<PageB> {
  DraftViewModel get draft =>
      viewModelBinding.watch(draftViewModelSpec(widget.documentId));

  @override
  Widget build(BuildContext context) => TextFormField(
        initialValue: draft.title,
        onChanged: draft.updateTitle,
      );
}
```

- A and B resolve the same instance because they use the same resolved VM type
  and key. There is no need to use a cached API to retrieve an instance created
  by the other page.
- Both `watch(spec)` and `read(spec)` bind the instance to the current page. Use
  `watch` when the page must react to VM notifications; use `read` when it only
  invokes methods.
- While A and B both exist, each binding owns the instance. Disposing B removes
  only B's bind, so A keeps the instance alive. When A is also disposed, the
  final bind is removed and the instance is automatically reclaimed.
- A `key` defines shared identity; it does not retain the instance forever. If
  multiple edit flows can coexist, include a document or session ID in the key
  to prevent unrelated flows from sharing state.
- The resulting lifetime is the union of all participating page scopes. This
  is usually more appropriate than `aliveForever: true`. Use `aliveForever`
  with an explicit key only when the instance must survive with zero bindings.

See `examples/sharing_example.dart` for the complete example.

## Implementation workflow

1. Choose ViewModel style
- `with ViewModel`: mutable fields + `update`/`notifyListeners`.
- `StateViewModel<T>`: immutable state + `setState`, supports state diff/selective listeners.
- `ChangeNotifierViewModel`: only when extending `ChangeNotifier` behavior is required.

2. Define `ViewModelSpec`
- `ViewModelSpec<T>(builder: ...)` for no args.
- `ViewModelSpec.arg/arg2/arg3/arg4` for parameterized construction.
- Arguments only affect identity through the explicit key callback; choose a
  stable key from the entity ID when different arguments need different VMs.
- Identity is resolved generic VM type `T` + effective `key`; `tag` and the
  builder's runtime result type do not participate in identity.
- With `aliveForever: false`, when factory `key()` returns `null`, repeated
  access to the same `T` reuses one instance within a binding and remains
  isolated across bindings.
- Use `key` for cross-binding sharing or multiple same-`T` instances in one
  binding. It does not keep an instance alive.
- Use `tag` for grouped lookup.
- Use `aliveForever: true` only for intentional long-lived retention and pair
  it with an explicit key. It skips automatic disposal at zero binding
  references; `recycle` still force-disposes.

3. Integrate with host
- Widget page: `State<T> with ViewModelStateMixin`.
- Simple widget case: `StatelessWidget with ViewModelStatelessMixin`.
- Non-widget classes (bootstrap/service/test): `with ViewModelBinding` and call `dispose()` manually when done.

4. Choose the primary access API
- **Recommended:** `watch(spec)` creates/gets, binds, and listens for reactive
  owner updates.
- **Recommended:** `read(spec)` creates/gets and binds without a ViewModel
  listener.
- Prefer a stable spec and resolve it explicitly with `watch(spec)` or
  `read(spec)` in normal application code.
- **Advanced cached lookup (normally avoid):** cached APIs bypass spec-based
  resolution and can only query instances already created by another path.
  Use them only for an intentional cross-owner cache query when cache identity,
  creation order, absence, tag multiplicity, and lifecycle coupling are all
  understood.
  - `watchCached`/`maybeWatchCached`: a hit establishes the same ownership and
    ViewModel listener as `watch`; the `maybe` variant returns `null` on a miss.
  - `readCached`/`maybeReadCached`: a hit establishes the same ownership as
    `read`, without a ViewModel listener; handle disposal/recycle is still
    observed.
  - `watchCachesByTag`/`readCachesByTag`: every matched instance is bound; only
    the watch variant listens to ViewModel notifications, while both variants
    observe handle disposal/recycle.
- `listen/listenState/listenStateSelect`: side-effect listeners, auto-cleaned on binding dispose.
- Equality priority is local full-state `equals` → global
  `ViewModelConfig.equals` → `identical`, and explicit selector `equals` →
  global `ViewModelConfig.equals` → `==`. The global fallback defaults to
  `null`.
- Pass the optional typed `equals` directly to `listenStateSelect` when a
  selector needs a local rule that overrides the global fallback.
- `recycle(vm)`: force unbind all and dispose; next `watch/read` gets fresh instance.
- There is no in-place replacement capability. Use a new explicit key for an
  independent instance. If global replacement is intentional, call `recycle`
  and let getter-based `watch(spec)`/`read(spec)` create a new handle and
  dependency tree on the next access.

5. Handle dependencies and sharing
- Model each independent functional capability as a ViewModel when it benefits
  from managed lifecycle, state notifications, dependency injection, or reuse.
- In a ViewModel, `viewModelBinding` is a stable, generation-scoped dependency
  binding initialized under the construction Zone.
- ViewModel-to-ViewModel calls (`read/watch/listen`) establish a parent-owned
  lifecycle edge and mirror the parent's current root bindings.
- Resolve nested ViewModels through non-caching getters; do not retain them in
  `late final`, `final`, or `??=` fields.
- Do not constructor-inject or otherwise hand a resolved ViewModel instance to
  another lifecycle owner. Let the receiving owner resolve a stable spec using
  its own binding. For shared identity, use the same keyed spec at both owners.
- With `aliveForever: false` and `key() == null`: one instance per resolved
  generic VM type `T` per binding.
- With same `T` + same `key`: shared identity across bindings.
- For temporary sharing across sibling pages or independent bindings, let every
  participant resolve the same keyed spec with `watch/read`. Their bindings
  collectively define the local lifetime; the instance auto-disposes after
  the final participant unbinds.
- Multiple instances of the same `T` in one binding need distinct keys.
- Every `aliveForever` instance requires an explicit key, regardless of
  whether it is resolved by a root binding or another ViewModel.

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
- Use Flutter's `ValueNotifier` + `ValueListenableBuilder` for widget-local
  values, or an explicit `StateViewModel` + `ViewModelSpec` for managed state.
  Add a `key` when cross-binding sharing, multiple same-type instances in one
  binding, or stable keyed cached lookup is required.

8. App-level setup
- Call `ViewModel.initialize(...)` once at app startup (subsequent calls are ignored).
- Configure `ViewModelConfig` when needed:
  - `isLoggingEnabled`
  - `equals` (global equality fallback, default `null`)
  - `onError` (with `ErrorType.listener` / `ErrorType.lifecycle` / `ErrorType.dispose` / `ErrorType.pauseResume`)
- If using `equals: (a, b) => a == b`, ensure state classes implement `==` and `hashCode`.

9. Testing and mocking
- Prefer pure Dart unit tests with `ViewModelBinding()` (no `testWidgets` required for many cases).
- Run the suite in one test process and in runner order. Registry, config,
  lifecycle observers, reset state, and legacy spec proxies are process-global;
  do not use parallel test files, sharding, or concurrent groups. Use
  `flutter test --concurrency=1` (locally in this repo: `ff test --concurrency=1`).
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
- Use `watch(spec)` / `read(spec)` as the default entry points and keep the
  stable spec available at the call site.
- Default feature-module specs to no `key` and no `aliveForever`, allowing the
  binding to own creation, reuse, and disposal.
- Expose ViewModels through typed, non-caching getters that call
  `viewModelBinding.read/watch`.
- Keep `watch` for reactive UI, `read` for imperative actions.
- For field-level updates (`listenStateSelect`, `StateViewModelValueWatcher`,
  selector-based rebuilds), read the ViewModel with `read` and let the
  selector mechanism drive updates; avoid `watch` on the same ViewModel.
- Set explicit `key` whenever instance sharing is a requirement.
- Prefer keyed, binding-scoped sharing over `aliveForever` when the instance
  only needs to live while one or more participating pages are alive.
- Dispose non-widget bindings explicitly.
- Use `listenStateSelect` for side effects on selected state fields; pass its
  optional typed `equals` when the selected value needs a local rule that
  overrides the global fallback.

Don't:
- Pass resolved ViewModel instances between owners through constructors,
  widget/route arguments, service fields, or similar hand-offs; this bypasses
  binding ownership and can retain a disposed or recycled generation.
- Introduce a global singleton or service locator for ViewModel modules by
  default; compose modules through `viewModelBinding` instead.
- Claim `read` is "non-binding" (it still binds and affects lifecycle).
- Pair selector-level rebuild tools with `watch`; this usually causes broader
  rebuilds than intended.
- Cache a ViewModel dependency in `late final`, `final`, or `??=`; the active
  object can be disposed after recycle or across an async gap.
- Use cached APIs as a substitute for spec-based dependency resolution, or
  expect them to create a missing instance.
- Overuse `aliveForever` for page-scoped state.
- Forget `ViewModel.routeObserver` when relying on route pause behavior.

## Response pattern for implementation requests

When generating code for users:
- Default every normal resolution example to `watch(spec)` or `read(spec)`.
  Show a cached API only when the user explicitly needs an advanced lookup of
  an already-created cross-owner cache entry.
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
