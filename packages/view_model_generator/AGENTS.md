# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model_generator`.

## Scope

`view_model_generator` owns source generation for `@GenSpec` and must stay aligned with both `view_model_annotation` and the runtime expectations in `view_model`.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` for generated spec semantics and `@GenSpec` behavior.
- If the task is about publishing, also follow `.agents/skills/publish-process/SKILL.md`.

## Key Files

- `lib/view_model_generator.dart`
- `lib/src/view_model_generator.dart`
- `lib/src/spec_generator.dart`
- `test/view_model_generator_test.dart`
- `README.md`
- `CHANGELOG.md`
- `example/`

## Working Rules

- Keep generated output consistent with the public examples in `README.md`.
- When changing generation rules, update tests first or alongside the implementation.
- Coordinate annotation-related changes with `packages/view_model_annotation`.
- Do not hand-edit generated example outputs unless you regenerated them intentionally.
- Avoid unrelated dependency updates.

## Validation

- Preferred package check: `dart test`
- If generation behavior changes, also verify the local `example/` with `dart run build_runner build`
