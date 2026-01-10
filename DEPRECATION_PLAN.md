# Deprecation Plan for `isSingleton` Parameter

## Overview

The `isSingleton` parameter in `ViewModelProvider` and related classes is deprecated in favor of the more flexible `key` parameter. This document outlines the deprecation timeline and migration path.

## Rationale

The `key` parameter provides more control and flexibility:
- `isSingleton` is a boolean flag with limited expressiveness
- `key` allows fine-grained control over instance sharing
- `key` supports multiple shared instances with different keys
- The `key` pattern is more consistent with Flutter's widget system

## Timeline

### ✅ Phase 1: Soft Deprecation (Current - v0.12.0)
**Status**: ACTIVE
**Started**: Version 0.12.0
**Actions**:
- ✅ Add `@Deprecated('Use key instead')` annotations to all `isSingleton` parameters
- ✅ Update documentation with migration examples
- ⚠️ Code still compiles with warnings
- ✅ All existing code continues to work

**For Users**:
- Start planning migration
- New code should use `key` instead of `isSingleton`
- Update documentation and examples

---

### 🔄 Phase 2: Hard Deprecation (v0.15.0 - Q2 2026)
**Status**: PLANNED
**Target Date**: April 2026
**Actions**:
- Add runtime warnings when `isSingleton` is used
- Create automated migration tool (codemod)
- Update all official examples to use `key`
- Publish migration guide

**For Users**:
- Must migrate before v1.0.0
- Use provided migration tool for automatic conversion
- Runtime warnings appear in console when `isSingleton` is used

---

### ❌ Phase 3: Removal (v1.0.0 - Q3 2026)
**Status**: PLANNED
**Target Date**: July 2026
**Actions**:
- **BREAKING CHANGE**: Remove `isSingleton` parameter entirely
- Remove all deprecated code paths
- Clean up internal implementation
- Publish v1.0.0 with full changelog

**For Users**:
- Code using `isSingleton` will not compile
- Must complete migration to `key` parameter
- Follow migration guide below

---

## Migration Guide

### Simple Singleton Migration

**Before** (using `isSingleton`):
```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
  isSingleton: true,  // ❌ Deprecated
);
```

**After** (using `key`):
```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
  key: 'MyViewModel',  // ✅ Recommended - or use any unique object
);
```

Or use the shorthand:
```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
  key: MyViewModel,  // ✅ Use the type itself as key
);
```

---

### Non-Singleton Migration

**Before**:
```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
  isSingleton: false,  // ❌ Deprecated (this is the default)
);
```

**After**:
```dart
final myProvider = ViewModelProvider<MyViewModel>(
  builder: () => MyViewModel(),
  // ✅ Simply omit the key parameter - each widget gets its own instance
);
```

---

### Arg-Based Provider Migration

**Before**:
```dart
final userProvider = ViewModelProvider.arg<UserViewModel, String>(
  builder: (userId) => UserViewModel(userId),
  isSingleton: (userId) => true,  // ❌ Deprecated
);
```

**After**:
```dart
final userProvider = ViewModelProvider.arg<UserViewModel, String>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId',  // ✅ Each user gets a shared instance
);
```

---

### Multiple Shared Instances

The `key` parameter is more powerful than `isSingleton`:

**Before** (not possible with `isSingleton`):
```dart
// Could only have ONE singleton or MANY instances
```

**After** (flexible with `key`):
```dart
// Share instances per tab/category/etc.
final tabProvider = ViewModelProvider.arg<TabViewModel, String>(
  builder: (tabId) => TabViewModel(tabId),
  key: (tabId) => 'tab_$tabId',  // ✅ One instance per tab
);

// Usage:
vef.watch(tabProvider('home'));    // Shared for 'home' tab
vef.watch(tabProvider('profile')); // Shared for 'profile' tab
```

---

## Automated Migration Tool

### Installation (Available in v0.15.0)

```bash
dart pub global activate view_model_migration
```

### Usage

```bash
# Migrate a single file
view_model_migrate fix lib/my_file.dart

# Migrate entire project
view_model_migrate fix lib/

# Dry run (preview changes)
view_model_migrate fix lib/ --dry-run
```

### What the Tool Does

1. ✅ Converts `isSingleton: true` → `key: <TypeName>`
2. ✅ Removes `isSingleton: false` (default behavior)
3. ✅ Updates arg-based providers with lambda conversions
4. ✅ Preserves comments and formatting
5. ✅ Creates backup files (`.dart.backup`)

---

## Common Patterns

### Pattern 1: Global Singleton

```dart
// ❌ Old way
ViewModelProvider<AppConfigViewModel>(
  builder: () => AppConfigViewModel(),
  isSingleton: true,
)

// ✅ New way
ViewModelProvider<AppConfigViewModel>(
  builder: () => AppConfigViewModel(),
  key: 'app_config',  // Or: key: AppConfigViewModel
)
```

### Pattern 2: Per-Route Instance

```dart
// ✅ Each route gets its own instance (no key needed)
ViewModelProvider<PageViewModel>(
  builder: () => PageViewModel(),
  // No key = new instance per widget
)
```

### Pattern 3: Per-Entity Sharing

```dart
// ✅ Share by entity ID
ViewModelProvider.arg<ProductViewModel, String>(
  builder: (productId) => ProductViewModel(productId),
  key: (productId) => 'product_$productId',
)
```

---

## FAQ

### Q: When should I use `key` vs no key?

**Use `key`** when:
- Multiple widgets should share the same ViewModel instance
- You want to preserve state across widget rebuilds
- You need a singleton or per-entity instance

**Omit `key`** when:
- Each widget needs its own independent instance
- State should be widget-local
- Like using `const UniqueKey()` in Flutter

### Q: What if I forget to migrate?

- **v0.15.0**: Runtime warnings in console
- **v1.0.0**: Compilation errors - code won't build

### Q: Can I use custom objects as keys?

Yes! Any object can be a key:
```dart
key: MyCustomKey(),
key: userId,
key: 'my-string-key',
key: 42,
key: MyViewModel,  // The type itself
```

### Q: Is there a performance difference?

No. Both `isSingleton` and `key` use the same underlying instance caching mechanism.

---

## Checklist for Migration

- [ ] Review all usages of `isSingleton` in your codebase
- [ ] Run `view_model_migrate fix lib/` (when available in v0.15.0)
- [ ] Review and test the automated changes
- [ ] Update custom ViewModelFactory implementations
- [ ] Update documentation and examples
- [ ] Test all affected features
- [ ] Remove `.dart.backup` files after verification
- [ ] Commit changes with message: "Migrate from isSingleton to key parameter"

---

## Support

If you encounter issues during migration:

1. **Check the migration guide**: This document covers most common scenarios
2. **Use the automated tool**: Handles 95%+ of cases automatically
3. **Search GitHub Issues**: https://github.com/yourusername/view_model/issues
4. **Ask for help**: Create an issue with the `migration` label

---

## Version Support Matrix

| Version | isSingleton Status | Recommended Action |
|---------|-------------------|-------------------|
| v0.12.0 | Deprecated (warnings) | Start planning migration |
| v0.15.0 | Hard deprecated (runtime warnings) | Migrate using tool |
| v1.0.0  | ❌ Removed | Must complete migration |

---

*Last Updated: 2026-01-10*
*Target v1.0.0 Release: 2026-07-01*
