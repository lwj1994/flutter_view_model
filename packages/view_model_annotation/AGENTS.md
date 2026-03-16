# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model_annotation`.

## Scope

`view_model_annotation` is the lightweight annotation package used by the generator. Its API should stay small and stable.

## Skills

- Use `.agents/skills/view_model/SKILL.md` when annotation changes affect generated `ViewModelSpec` behavior.
- If the task is about publishing, also follow `.agents/skills/publish-process/SKILL.md`.

## Key Files

- `lib/view_model_annotation.dart`
- `lib/src/annotation.dart`
- `README.md`
- `CHANGELOG.md`
- `pubspec.yaml`
- `example/`

## Working Rules

- Keep this package dependency-light and additive when possible.
- Treat annotation API changes as cross-package changes: check `view_model_generator` and, if needed, `view_model`.
- Prefer simple, explicit annotation contracts over magic behavior.
- Do not change versions unless the task is explicitly release-related.

## Validation

- There is no dedicated `test/` directory here now.
- Validate annotation changes through `packages/view_model_generator/test/` and the local `example/` when relevant.
