## 0.15.0-dev.0
- Refactor: Generate `ViewModelSpec` (xxxSpec) instead of `ViewModelProvider` (xxxProvider)
- Support both `@GenSpec` and `@GenProvider` (deprecated) annotations
- Update internal logic to use `ViewModelBinding` and `ViewModelSpec` naming

## 0.14.2
- Update version for consistency

## 0.14.1
- Minor documentation updates

## 0.14.0-dev.1
- Development release

## 0.14.0-dev.0
- Development release

## 0.13.0
- Support `aliveForever` in generator

## 0.3.1
- Fix bugs

## 0.3.0
- Support nullable args

## 0.2.4
- Add `$view_model_Singleton_` prefix to the generated key for Singleton ViewModels to prevent naming collisions.

## 0.2.3
- fix bugs

## 0.2.2
- Support `isSingleton`

## 0.2.1
- fix bugs

## 0.2.0
* Add key/tag support in `@GenProvider` for both strings and
  non-string expressions
* Introduce `Expression('code')` marker to unwrap expressions into builder
  closures
* Prefer `factory ClassName.provider(...)` when present
* Support up to 4 args with `arg`, `arg2`, `arg3`, `arg4`
* Exclude `super` forwarded parameters from spec arguments
* Special naming: `PostViewModel` -> `postSpec`



## 0.1.1
* fix bugs
## 0.1.0

* Initial release.
