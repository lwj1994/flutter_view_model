## 1.3.2

- Add six warnings: `view_model_listen_in_build`, `view_model_instance_handoff`,
  `view_model_identity_collision`, `view_model_selector_with_watch`,
  `view_model_undisposed_binding`, and `view_model_temporary_spec`.
- Add the opt-in `view_model_cached_lookup` info for cached queries. Enable it
  through the plugin's `diagnostics` map.
- `view_model_cached_instance` also reports VMs from host extensions and single
  cached queries.
- Add IDE quick fixes for `view_model_cached_instance`,
  `view_model_alive_forever_key`, `view_model_selector_with_watch`, and
  `view_model_temporary_spec`.
- Add the `view_model_lint_fix` batch command (`dart pub global run
  view_model_lint:fix [--dry-run]`), because `dart fix` cannot apply analyzer
  plugin fixes.
- Add `RULES.md` with good and bad examples for every rule.
- This release ships only `view_model_lint`; `view_model`,
  `view_model_annotation`, and `view_model_generator` stay at 1.3.1.

## 1.3.1

- Remove `view_model_parameterized_spec_key`. Parameterized specs may omit a
  key without a diagnostic. Keep the four remaining warnings, including the
  explicit key requirement for `aliveForever`.

## 1.3.0

- Add a native analyzer plugin with five ViewModel usage warnings.
- Support IDE diagnostics, `dart analyze`, per-rule configuration, and ignores.
- Add rule regression tests and real analyzer-process integration tests.
- Support analyzer 8.4 through 10.x, including native plugin loading on newer Dart SDKs.
