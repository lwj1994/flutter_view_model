# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model_annotation/example`.

## Scope

This is a small example project used to verify annotation and generation flow for `view_model_annotation`.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` when the example is used to validate `@GenSpec` behavior.

## Key Files

- `lib/example.dart`
- `lib/example.vm.dart`
- `pubspec.yaml`

## Working Rules

- Treat this directory as a validation example, not a production app.
- Do not hand-edit `lib/example.vm.dart` unless it was intentionally regenerated as part of the task.
- Keep local path dependencies and `dependency_overrides` working against sibling packages.

## Validation

- Preferred generation check: `dart run build_runner build`
- Re-run generation whenever annotation or generator behavior changes.
