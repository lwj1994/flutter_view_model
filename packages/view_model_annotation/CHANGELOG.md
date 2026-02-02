## 0.14.2
- Update version for consistency

## 0.14.1
- Minor documentation updates

## 0.14.0-dev.1
- Development release

## 0.14.0-dev.0
- Development release

## 0.13.0
- Support `aliveForever`

## 0.2.2
- Support `isSingleton`

## 0.2.1
- Rename `Expr` to `Expression`

## 0.2.0
- Add `key` and `tag` support in `@GenProvider` for both strings and
  non-string expressions.
- Introduce `Expression('code')` marker to unwrap expressions into builder closures.
- Prefer `factory ClassName.provider(...)` when present.
- Support up to 4 args with `arg`, `arg2`, `arg3`, `arg4`.
- Exclude `super` forwarded parameters from spec arguments.
- Special naming: `PostViewModel` -> `postSpec`.

## 0.1.0

- Initial release: extracted `GenProvider` and `genProvider` annotations
  from generator package to a standalone `view_model_annotation` package.
- Added README and example.
