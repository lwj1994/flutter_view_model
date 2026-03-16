# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model`.

## Scope

`view_model` is the main Flutter package in this repo. It owns the runtime model, binding system, lifecycle management, pause-resume behavior, and most of the public API surface.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` for architecture, lifecycle, `watch`/`read`, `ViewModelSpec`, testing, and generator integration.
- If the task is about publishing, also follow `.agents/skills/publish-process/SKILL.md`.

## Key Files

- `lib/view_model.dart`
- `lib/src/log.dart`
- `test/`
- `README.md`
- `CHANGELOG.md`
- `pubspec.yaml`

## Working Rules

- Preserve public API behavior unless the task explicitly requires a breaking change.
- Match the existing architecture and terminology from `README.md`.
- When changing lifecycle, binding, caching, pause-resume, or listener behavior, update or add tests in `test/`.
- Keep `view_model_annotation` version aligned when doing release work.
- Avoid package-level dependency churn unless the task is explicitly about releases or compatibility.

## Validation

- Preferred package check: `flutter test`
- If behavior is tied to generated specs, also verify the generator package or example that covers it.
