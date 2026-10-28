# view_model_lint

Recommended native analyzer checks for applications and business packages using
`view_model`. Requires Dart 3.10 / Flutter 3.38 or newer. The plugin runs in the
analysis process and adds no runtime dependency or runtime SDK requirement.

## Enable the plugin

Add this to the consuming package's root `analysis_options.yaml`, preserving
its existing includes and rules:

```yaml
plugins:
  view_model_lint:
    version: ^1.3.3
```

For local plugin development, replace `version` with
`path: /absolute/path/to/flutter_view_model/packages/view_model_lint`.
The repository examples use `path: ../../packages/view_model_lint`. No analyzer or
custom_lint dependency is needed in the consuming package's `pubspec.yaml`.
Restart the IDE's Dart Analysis Server, then run from the consuming package root:

```sh
dart analyze --fatal-infos --fatal-warnings
```

Use this command in CI as well. With this workstation's aliases, run
`zsh -ic 'fd analyze --fatal-infos --fatal-warnings'`. Avoid targeting only
`lib` or `test`: on the verified Dart 3.11 toolchain that invocation can skip
loading the package-root plugin. Ten diagnostics are enabled as warnings;
`view_model_cached_lookup` is an opt-in info.

## Rules

See [RULES.md](RULES.md) for good and bad examples of every rule.

| Diagnostic | Meaning and recommended fix |
| --- | --- |
| `view_model_dependency_cycle` | A statically visible parent-to-child type cycle. Break the cycle or review whether keys/bindings identify distinct instances. |
| `view_model_cached_instance` | A VM from `read/watch`, their host extensions, or a single cached query is stored in a field, top-level variable, or field assignment. Use a getter that resolves on every access. |
| `view_model_alive_forever_key` | Literal `aliveForever: true`, including a simple callback, has no non-null key. Supply an explicit key. |
| `view_model_unmanaged_construction` | A VM is constructed outside a spec builder, `ViewModelFactory.build`, or an annotated `@GenSpec` factory named `spec`. Resolve a stable spec through a binding. |
| `view_model_listen_in_build` | `listen`, `listenState`, or `listenStateSelect` runs in `build`, `didUpdateWidget`, `didChangeDependencies`, a binding's `onUpdate`, or a getter. Bindings do not deduplicate listeners, so each run adds one. Register once in `initState` or `onCreate`. |
| `view_model_instance_handoff` | A constructor parameter has a ViewModel type, so a resolved instance is handed to another owner. Pass a spec, key, or plain data and resolve through the receiver's binding. |
| `view_model_identity_collision` | One binding resolves the same VM type through two different unkeyed specs, or through one unkeyed parameterized spec with different arguments. Every such resolution returns the first instance. Add a key that identifies each instance. |
| `view_model_selector_with_watch` | `StateViewModelValueWatcher` receives a VM resolved by a `watch` variant, so every notification also rebuilds the owner. Resolve it with `read`. |
| `view_model_undisposed_binding` | A created `ViewModelBinding` is a temporary or is stored in a local variable or instance field that is never disposed and never handed to another owner. A binding held by a top-level variable or static field is an app-wide owner and is not reported. Call `dispose()`, for example in `tearDown` or `addTearDown`. |
| `view_model_temporary_spec` | A spec (`ViewModelSpec`, `ViewModelSpec.arg`, `ViewModelProvider`) is constructed anywhere other than the initializer of a top-level variable or static field, for example inline at a `read`/`watch` call, in a local variable or instance field, or in a non-generic function. A temporary spec is rebuilt on every evaluation and cannot be replaced by `setProxy`. Declare it once as a top-level or static final. A custom `ViewModelFactory` resolves by its own `key()` and may be constructed at the call. |
| `view_model_cached_lookup` (opt-in info) | A cached query such as `readCached`, `maybeWatchCached`, or `readCachesByTag` only finds instances another owner created. Prefer `watch/read(spec)`; keep cached lookup for intentional cross-owner queries. |

Parameterized specs may omit `key` without a diagnostic. Use an argument-derived
key when separate instances are intended. The `aliveForever` key requirement
still applies to both ordinary and parameterized specs.

Disable individual rules through the plugin's `diagnostics` map, for example
`view_model_cached_instance: false`. Enable the opt-in rule the same way:

```yaml
plugins:
  view_model_lint:
    version: ^1.3.3
    diagnostics:
      view_model_cached_lookup: true
```

For a narrowly scoped exception, use
`// ignore: view_model_lint/view_model_cached_instance` with a reason.
Remove old `view_model_parameterized_spec_key` settings and suppressions when
upgrading; that diagnostic is no longer registered.

## Quick fixes

Four diagnostics offer a quick fix from the IDE lightbulb:

| Diagnostic | Fix |
| --- | --- |
| `view_model_cached_instance` | Turns a `final` or `late final` field, or a top-level variable, initialized by a resolution into a getter. |
| `view_model_alive_forever_key` | Adds a key named after the spec variable, such as `'auth'` for `authSpec` or `(arg) => ('userCache', arg)` for a parameterized spec, or replaces a literal `null` key. |
| `view_model_selector_with_watch` | Changes a direct `watch` variant passed to the watcher into its `read` counterpart. |
| `view_model_temporary_spec` | Makes an instance-field spec `static`, or moves a spec that captures nothing from its scope into a private top-level `final`. |

A fix is offered only where the edit is safe; other occurrences still need a
manual change.

`dart fix` cannot apply analyzer plugin fixes, so the package ships a batch
command. Run it from the consuming package root:

```sh
dart pub global activate view_model_lint
view_model_lint_fix --dry-run   # list the fixes
view_model_lint_fix             # apply them
```

`dart pub global run view_model_lint:fix` works without the executable on
`PATH`; for a local checkout, activate it with
`dart pub global activate --source path <path to view_model_lint>`. The command
reads diagnostics from `dart analyze`, so disabled rules and ignore comments are
respected. It applies the fixes in rounds: edits that touch the same code wait
for the next round, and `--dry-run` lists only the first round. It then reports
how many diagnostics still need a manual change. Review the diff, then run
`dart format`.

## Analysis boundaries

Rules identify resolved framework types and methods, including inherited VMs and
prefixed imports. Unrelated same-named classes and methods are not framework
APIs. Managed builders, local temporaries, getters, callbacks, and transformed
plain values are not treated as stored VM instances.

Cycle detection follows the VM's own `viewModelBinding.read/watch` calls. Within
the current library, including its parts, it checks statically visible calls.
Across libraries it follows VM getters/fields that directly return a resolution.
Dynamic calls, indirect helper-function dependencies, key/tag identity, and
runtime overrides are outside this proof. Type cycles are advisory and cannot
replace runtime instance-cycle validation. Unknown key/aliveForever expressions
are not guessed to be null/true.

`view_model_listen_in_build` checks only the member's own body; listeners
registered inside a callback or a builder closure are not reported.
`view_model_identity_collision` compares resolutions within one class through
its own binding, or through one binding variable. It reads the spec declaration,
including imported specs, and stays silent when the key is set or unknown. An
argument varies when it reads a variable declared in an enclosing loop or
closure, or a parameter of the enclosing method other than `build`. Otherwise
arguments are compared by source text. `view_model_selector_with_watch` follows
final variables and single-expression getters in the current library.
`view_model_temporary_spec` also accepts a generic top-level function or static
method whose body only returns the spec, because Dart has no generic variables;
this is the form `@GenSpec` generates for generic ViewModels. A replacement
passed directly to `setProxy` is accepted because it is reached only through the
stable spec it overrides.
`view_model_undisposed_binding` treats a binding passed as an argument, returned,
or assigned elsewhere as handed to a new owner, and searches the whole library
for `dispose()` or a `dispose` tear-off on the stored variable.

## Development

```sh
dart pub get
dart analyze --fatal-infos --fatal-warnings lib test
dart test --concurrency=1
dart run bin/fix.dart --dry-run <consumer package>
```

Tests cover positive cases, false-positive boundaries, cross-file cycles and
specs, configuration, opt-in rules, every quick fix, plugin loading by a real
`dart analyze` process, and the batch fix command on a generated package. This package
shares its release version with `view_model`, `view_model_annotation`, and
`view_model_generator`. See the repository
[publishing skill](https://github.com/lwj1994/flutter_view_model/blob/main/.agents/skills/publish-process/SKILL.md)
for the coordinated release procedure.

Integration follows the [Dart analyzer plugin documentation](https://dart.dev/tools/analyzer-plugins).
