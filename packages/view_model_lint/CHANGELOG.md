## 1.3.1

- Remove `view_model_parameterized_spec_key`. Parameterized specs may omit a
  key without a diagnostic. Keep the four remaining warnings, including the
  explicit key requirement for `aliveForever`.

## 1.3.0

- Add a native analyzer plugin with five ViewModel usage warnings.
- Support IDE diagnostics, `dart analyze`, per-rule configuration, and ignores.
- Add rule regression tests and real analyzer-process integration tests.
- Support analyzer 8.4 through 10.x, including native plugin loading on newer Dart SDKs.
