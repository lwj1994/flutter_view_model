## 0.2.0
- Add `key` and `tag` support in `@GenProvider` for both strings and
  non-string expressions.
- Introduce `Expr('code')` marker to unwrap expressions into builder
  closures.
- Prefer `factory ClassName.provider(...)` when present.
- Support up to 4 args with `arg`, `arg2`, `arg3`, `arg4`.
- Exclude `super` forwarded parameters from provider arguments.
- Special naming: `PostViewModel` -> `postProvider`.

## 0.1.0

- Initial release: extracted `GenProvider` and `genProvider` annotations
  from generator package to a standalone `view_model_annotation` package.
- Added README and example.


