# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model_generator/example`.

## Scope

This example project demonstrates generator usage against the local workspace packages.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` when the example is used to validate generated `ViewModelSpec` behavior.

## Key Files

- `lib/example.dart`
- `lib/example.vm.dart`
- `pubspec.yaml`

## Working Rules

- Use this project to verify local generator output, not to prototype unrelated app features.
- Do not hand-edit `lib/example.vm.dart` unless it was intentionally regenerated.
- Keep local path dependencies and overrides aligned with sibling packages.

## Validation

- Preferred generation check: `dart run build_runner build`
- If Flutter-side behavior is involved, also run the relevant Flutter command from this directory.
