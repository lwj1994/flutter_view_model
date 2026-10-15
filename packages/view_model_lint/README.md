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
    version: ^1.3.0
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
loading the package-root plugin. All five diagnostics are enabled as warnings.

## Rules

| Diagnostic | Meaning and recommended fix |
| --- | --- |
| `view_model_dependency_cycle` | A statically visible parent-to-child type cycle. Break the cycle or review whether keys/bindings identify distinct instances. |
| `view_model_cached_instance` | A resolved `read/watch` VM is stored in a field, top-level variable, or field assignment. Use a getter that resolves on every access. |
| `view_model_alive_forever_key` | Literal `aliveForever: true`, including a simple callback, has no non-null key. Supply an explicit key. |
| `view_model_unmanaged_construction` | A VM is constructed outside a spec builder, `ViewModelFactory.build`, or an annotated `@GenSpec` factory named `spec`. Resolve a stable spec through a binding. |
| `view_model_parameterized_spec_key` | `arg/arg2/arg3/arg4` or a parameterized spec constructor has no key. Use an argument-derived key when distinct instances are intended. |

An unkeyed parameterized spec may deliberately reuse one instance per binding.
Disable only the rule that conflicts with the intended design:

```yaml
plugins:
  view_model_lint:
    version: ^1.3.0
    diagnostics:
      view_model_parameterized_spec_key: false
```

For a local exception, use
`// ignore: view_model_lint/view_model_parameterized_spec_key` or
`// ignore_for_file: view_model_lint/view_model_parameterized_spec_key`.
Explain the deliberate reuse in a nearby comment.

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

## Development

```sh
dart pub get
dart analyze --fatal-infos --fatal-warnings lib test
dart test --concurrency=1
```

Tests cover positive cases, false-positive boundaries, cross-file cycles,
configuration, and plugin loading by a real `dart analyze` process. This package
shares its release version with `view_model`, `view_model_annotation`, and
`view_model_generator`. See the repository
[publishing skill](https://github.com/lwj1994/flutter_view_model/blob/main/.agents/skills/publish-process/SKILL.md)
for the coordinated release procedure.

Integration follows the [Dart analyzer plugin documentation](https://dart.dev/tools/analyzer-plugins).
