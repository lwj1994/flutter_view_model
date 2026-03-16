# AGENTS.md

This file supplements the repository root `AGENTS.md` for `example/counter`.

## Scope

`counter` is a small Flutter example app demonstrating `view_model` usage patterns in a simple, readable setup.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` when changing state-management structure or `watch`/`read` usage.

## Key Files

- `lib/main.dart`
- `lib/counter_view_model.dart`
- `lib/counter_state.dart`
- `lib/counter_page.dart`
- `lib/settings_page.dart`
- `test/widget_test.dart`
- `README.md`
- `pubspec.yaml`

## Working Rules

- Keep the example easy to read and suitable for documentation-style learning.
- Prefer straightforward code over framework-heavy abstractions.
- Preserve the local path dependency on `../../packages/view_model`.
- If changing visible behavior, update the widget test when needed.

## Validation

- Preferred example check: `flutter test`
- Run `flutter run` when the task is primarily about UI or interaction flow.
