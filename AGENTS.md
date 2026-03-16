# AGENTS.md

Repository guidance for agents working in `/Volumes/mac-ext-ssd/document/GitHub/flutter_view_model`.

## Repository Scope

This repository is a Flutter monorepo centered on the `view_model` ecosystem.

Packages under `packages/`:

- `view_model`: main Flutter package
- `view_model_annotation`: annotation package for code generation
- `view_model_generator`: source_gen/build package for `@GenSpec`
- `view_model_devtools_extension`: local DevTools extension, not published

Examples under `example/`:

- `counter`
- `todo_list`

## Skills

A skill is a set of local instructions stored in a `SKILL.md` file. Use the smallest set of skills that fully covers the request.

Available repo-local skills:

- `Publish Process`
  - Description: workflow for publishing `view_model` packages in the correct order
  - Path: `.agents/skills/publish-process/SKILL.md`
- `view_model`
  - Description: build or refactor Flutter state management with the `view_model` package, including `ViewModel`, `ViewModelBinding`, `ViewModelSpec`, watch/read semantics, lifecycle, pause-resume, testing, and code generation
  - Path: `.agents/skills/view_model/SKILL.md`

## Skill Trigger Rules

Use a skill in the current turn when either condition is true:

- The user explicitly names the skill.
- The task clearly matches the skill description.

Do not carry skills across turns unless the user re-mentions them or the new request clearly triggers them again.

If multiple skills apply:

- Choose the minimal set that covers the request.
- State which skills you are using and in what order.

If a skill file is missing or blocked:

- Say so briefly.
- Continue with the best fallback approach.

## How To Use Skills

1. Open the relevant `SKILL.md`.
2. Read only what is necessary to complete the task.
3. When a skill references relative paths, resolve them relative to that skill directory first.
4. Load extra references only when needed.
5. Reuse scripts, examples, and assets from the skill folder when they exist.

## Repository Working Rules

- Read the codebase before making assumptions.
- Prefer existing patterns in the target package.
- Keep changes scoped to the relevant package.
- Do not update package dependency versions unless the task is explicitly about releases or compatibility.
- If working on `view_model` architecture, prefer the `view_model` skill as the source of truth.
- If working on publishing, prefer the `Publish Process` skill.

## Package-Specific Notes

### `packages/view_model`

- Primary library entrypoint: `lib/view_model.dart`
- Contains the main runtime and the broadest test coverage
- Depends on `view_model_annotation`

### `packages/view_model_annotation`

- Primary library entrypoint: `lib/view_model_annotation.dart`
- Keep it lightweight and stable
- Changes here can require coordinated updates in generator and main package

### `packages/view_model_generator`

- Primary library entrypoint: `lib/view_model_generator.dart`
- Generator behavior should remain aligned with `view_model_annotation`
- Test generated behavior when changing parsing or output

### `packages/view_model_devtools_extension`

- Local DevTools extension
- `publish_to: none`
- Depends on local path `../view_model`

## Publishing Notes

When publishing, follow `.agents/skills/publish-process/SKILL.md`.

Current expected publish order:

1. `view_model_annotation`
2. `view_model_generator`
3. `view_model`

Do not publish `view_model_devtools_extension`.
