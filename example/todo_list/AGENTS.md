# AGENTS.md

This file supplements the repository root `AGENTS.md` for `example/todo_list`.

## Scope

`todo_list` is a larger Flutter example app showing `view_model` usage in a more realistic, multi-screen flow.

## Skills

- Prefer `.agents/skills/view_model/SKILL.md` when changing state-management structure or `watch`/`read` usage.

## Key Files

- `lib/main.dart`
- `lib/todo_view_model.dart`
- `lib/todo_state.dart`
- `lib/todo_page.dart`
- `lib/search_page.dart`
- `lib/stats_page.dart`
- `test/widget_test.dart`
- `README.md`
- `pubspec.yaml`

## Working Rules

- Keep this example representative of recommended `view_model` usage, not just minimally working.
- Preserve readability across multiple screens and states.
- Keep the local path dependency on `../../packages/view_model`.
- Update tests when changing user-visible flows.

## Validation

- Preferred example check: `flutter test`
- Run `flutter run` when the task is primarily about UI behavior or navigation.
