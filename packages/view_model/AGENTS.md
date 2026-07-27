# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model`.

## Scope

`view_model` is the main Flutter package in this repo. It owns the runtime model, binding system, lifecycle management, pause-resume behavior, and most of the public API surface.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` for architecture, lifecycle, `watch`/`read`, `ViewModelSpec`, testing, and generator integration.
- If the task is about publishing, also follow `.agents/skills/publish-process/SKILL.md`.

## Key Files

- `lib/view_model.dart`
- `lib/src/view_model/view_model_binding.dart`
- `lib/src/view_model/construction_transaction.dart`
- `lib/src/view_model/update_transaction.dart`
- `lib/src/log.dart`
- `test/`
- `README.md`
- `ARCHITECTURE_GUIDE.md`
- `ARCHITECTURE_GUIDE_ZH.md`
- `CHANGELOG.md`
- `dart_test.yaml`
- `pubspec.yaml`

## Working Rules

- Preserve public API behavior unless the task explicitly requires a breaking change.
- Match the existing architecture and terminology from `README.md`.
- When changing lifecycle, binding, caching, pause-resume, or listener behavior, update or add tests in `test/`.
- A child resolved through a ViewModel belongs to that parent object generation:
  its lifetime cannot be shorter than the parent, and the parent's external
  root bindings must be mirrored to it with source-aware references.
- Every `aliveForever` ViewModel must have an explicit key. Root and nested
  resolution apply the same validation before invoking the builder, and Store
  creation must enforce the invariant for lower-level factories.
- Keep the child lifecycle diagrams and API matrices in both READMEs and both
  architecture guides synchronized with runtime behavior.
- Keep `view_model_annotation` version aligned when doing release work.
- Avoid package-level dependency churn unless the task is explicitly about releases or compatibility.

## Validation

- ViewModel tests must execute serially because registry/config/lifecycle state
  is process-global. `dart_test.yaml` enforces one suite at a time; do not
  override it with parallel groups or sharding.
- Preferred package check: `zsh -ic 'ff test --concurrency=1'`
- If behavior is tied to generated specs, also verify the generator package or example that covers it.
