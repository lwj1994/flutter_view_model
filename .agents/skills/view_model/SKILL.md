---
name: view_model
description: Build or refactor Flutter state management with the view_model package, including ViewModel/ViewModelBinding mixins, ViewModelSpec sharing, watch/read semantics, lifecycle, pause-resume, testing, and code generation.
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
- "StateViewModel / listenStateSelect / ValueWatcher"
- "生命周期、自动销毁、pause/resume"
- "`@GenSpec` 或 view_model_generator"

## Core model (must stay accurate)

- Architecture is type-keyed instance registry + binding-based reference counting.
- Two base mixins:
  - `with ViewModel`: managed instance (lifecycle + notify + DI access).
  - `with ViewModelBinding`: binding host (watch/read/listen/recycle APIs).
- Widget mixins are wrappers over `ViewModelBinding`:
  - `ViewModelStateMixin` (recommended default for widgets).
  - `ViewModelStatelessMixin` (lightweight, but has multi-mount caveat).

## Implementation workflow

1. Choose ViewModel style
- `with ViewModel`: mutable fields + `update`/`notifyListeners`.
- `StateViewModel<T>`: immutable state + `setState`, supports state diff/selective listeners.
- `ChangeNotifierViewModel`: only when extending `ChangeNotifier` behavior is required.

2. Define `ViewModelSpec`
- `ViewModelSpec<T>(builder: ...)` for no args.
- `ViewModelSpec.arg/arg2/arg3/arg4` for parameterized construction.
- Use `key` for shared instance identity.
- Use `tag` for grouped lookup.
- Use `aliveForever: true` only for real process-lifetime singletons.

3. Integrate with host
- Widget page: `State<T> with ViewModelStateMixin`.
- Simple widget case: `StatelessWidget with ViewModelStatelessMixin`.
- No-custom-state option: `ViewModelBuilder<T>(spec, builder: ...)`.
- Cached-only builder option: `CachedViewModelBuilder<T>(shareKey: ... | tag: ..., builder: ...)`.
- Non-widget classes (bootstrap/service/test): `with ViewModelBinding` and call `dispose()` manually when done.

4. Choose access API correctly
- `watch(spec)`: create/get + bind + listen (reactive rebuild/`onUpdate`).
- `read(spec)`: create/get + bind, no listener.
- `watchCached/readCached`: lookup existing instance only (no creation).
- `maybeWatchCached/maybeReadCached`: null-safe cached lookup.
- `watchCachesByTag/readCachesByTag`: batch tag lookup.
- `listen/listenState/listenStateSelect`: side-effect listeners, auto-cleaned on binding dispose.
- `recycle(vm)`: force unbind all and dispose; next `watch/read` gets fresh instance.

5. Handle dependencies and sharing
- In a ViewModel, `viewModelBinding` is available via Zone from parent binding.
- ViewModel-to-ViewModel calls (`read/watch/listen`) are part of the same binding lifecycle chain.
- Without `key`: per-binding isolated instance.
- With same `key`: cross-binding shared instance.
- Static lookup (`ViewModel.readCached`, `ViewModel.maybeReadCached`) is lookup-only (no bind, no create).

6. Lifecycle and cleanup
- Lifecycle hooks: `onCreate`, `onBind`, `onUnbind`, `onDispose`.
- Prefer `addDispose(() { ... })` for subscriptions/controllers/stream cleanup.
- Auto-dispose occurs when handle `bindingIds` becomes empty and `aliveForever` is false.

7. Performance and visibility
- For route-based pause/resume, register:
  - `MaterialApp(navigatorObservers: [ViewModel.routeObserver])`
- Built-in pause providers: route cover, ticker mode, app lifecycle.
- Use `StateViewModelValueWatcher` for selector-level rebuilds (usually pair with `read`, not `watch`).
- `ObservableValue` + `ObserverBuilder(1/2/3)` for lightweight reactive values; same `shareKey` means shared underlying state.

8. App-level setup
- Call `ViewModel.initialize(...)` once at app startup (subsequent calls are ignored).
- Configure `ViewModelConfig` when needed:
  - `isLoggingEnabled`
  - `equals` (state equality strategy)
  - `onListenerError`
  - `onDisposeError`
- If using `equals: (a, b) => a == b`, ensure state classes implement `==` and `hashCode`.

9. Testing and mocking
- Prefer pure Dart unit tests with `ViewModelBinding()` (no `testWidgets` required for many cases).
- Always `binding.dispose()` in teardown.
- For spec override: `spec.setProxy(...)` and `spec.clearProxy()`.

10. Code generation (optional)
- Annotate with `@GenSpec`, add `part '*.vm.dart'`, then run `dart run build_runner build`.
- Generator creates `xxxViewModelSpec` and supports up to 4 constructor args.

## Do/Don't checklist

Do:
- Keep `watch` for reactive UI, `read` for imperative actions.
- Set explicit `key` whenever instance sharing is a requirement.
- Dispose non-widget bindings explicitly.
- Use `listenStateSelect` for side effects on selected state fields.

Don't:
- Claim `read` is "non-binding" (it still binds and affects lifecycle).
- Use cached APIs expecting auto-create behavior.
- Overuse `aliveForever` for page-scoped state.
- Forget `ViewModel.routeObserver` when relying on route pause behavior.

## Response pattern for implementation requests

When generating code for users:
- Prefer complete, runnable snippets with:
  - imports
  - ViewModel class
  - Spec declaration
  - widget/binding usage
  - disposal/setup notes
- State why `watch` or `read` was chosen.
- If introducing sharing, show explicit `key` and lifecycle implications.
