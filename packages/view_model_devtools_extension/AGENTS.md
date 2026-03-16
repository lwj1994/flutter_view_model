# AGENTS.md

This file supplements the repository root `AGENTS.md` for `packages/view_model_devtools_extension`.

## Scope

`view_model_devtools_extension` is a local Flutter DevTools extension for inspecting `view_model` state. It is not published.

## Key Files

- `lib/main.dart`
- `lib/src/extension_main.dart`
- `lib/services/view_model_service.dart`
- `lib/widgets/`
- `test/view_model_screen_test.dart`
- `pubspec.yaml`

## Working Rules

- Keep the local path dependency on `../view_model` intact unless the task explicitly changes workspace structure.
- Preserve DevTools extension entrypoints and widget wiring.
- Favor readable UI/debugging behavior over abstraction-heavy refactors.
- Since `publish_to: none`, do not introduce publishing workflow changes here unless explicitly requested.

## Validation

- Preferred package check: `flutter test`
- If UI behavior changes, ensure the existing screen test still matches the intended inspector behavior.
