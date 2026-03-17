# AGENTS.md

Repository guidance for agents working in the `view_model` monorepo.

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

## getInstance 获取逻辑

实例获取分为三层：`ViewModelBinding` → `AutoDisposeInstanceController` → `Store`。

### 公开 API（ViewModelBinding）

| 方法 | 创建实例 | bind | addRef | ViewModel listener | recreate listener |
|------|---------|------|--------|-------------------|------------------|
| `watch(factory)` | 是 | 是 | 是 | 是（触发 widget rebuild） | 是 |
| `watchCached(key/tag)` | 否 | 是 | 是 | 是 | 是 |
| `read(factory)` | 是 | 是 | 是 | 否 | 是 |
| `readCached(key/tag)` | 否 | 是 | 是 | 否 | 是 |
| `watchCachesByTag(tag)` | 否 | 是 | 是 | 是 | 是 |
| `readCachesByTag(tag)` | 否 | 是 | 是 | 否 | 是 |

关键区别：

- **watch vs read**：watch 注册 ViewModel listener（`_addListener`），ViewModel 调用 `notifyListeners()` 时会触发 widget rebuild；read 不注册，不触发 rebuild。
- **有 factory vs Cached**：有 factory 时可以创建新实例；Cached 只查找已有缓存。
- **recreate listener**：注册在 `InstanceHandle`（ChangeNotifier）上，仅在实例被 recreate/dispose 时触发，不响应 ViewModel 自身的 `notifyListeners()`。
- **`readCachesByTag` 是批量版 `read`**：它不会响应 ViewModel 自身的 `notifyListeners()`，但会注册 recreate listener，因此实例被 recreate/dispose 时仍会触发 binding 更新；同时它也会执行 `bind + addRef`，并在 binding dispose 时自动 `unbind/removeRef`。

### 内部调用链

```
watch/read/watchCached/readCached
  → ViewModelBinding._getViewModel(listen)
    → 按 key 查找 → _requireExistingViewModel
    → 有 factory → _createViewModel → AutoDisposeInstanceController.getInstance
    → 按 tag 回退 → _requireExistingViewModel
    → listen=true 时追加 _addListener（ViewModel listener）

watchCachesByTag/readCachesByTag
  → AutoDisposeInstanceController.getInstancesByTag(listen)
    → bind + addRef（始终执行）
    → 追加 _attachRecreateListener
  → listen=true 时追加 _addListener（仅 watchCachesByTag）
```

### AutoDisposeInstanceController.getInstance

1. 将 `viewModelBinding.id` 注入 factory arg 的 `bindingId`
2. 调用 `instanceManager.getNotifier(factory)` → `Store.getNotifier()`
   - 缓存命中：直接返回已有 handle，按需 `bind(bindingId)`
   - 缓存未命中：调用 `factory.builder()` 创建实例，包装为 `InstanceHandle`，触发 `onCreate` + `bind`
3. `addRef(viewModelBinding)` — 将 binding 加入 ViewModel 的 refHandler（依赖追踪）
4. `_attachRecreateListener(notifier)` — 在 InstanceHandle 上注册 listener，仅响应 recreate/dispose 事件

### 注意事项

- `getInstance` 内部无条件注册 recreate listener，`listen` 参数只在 ViewModelBinding 层控制 ViewModel listener（`_addListener`）。公开 API 中，`watchCachesByTag` 和 `readCachesByTag` 都会通过 `getInstancesByTag(listen: true)` 注册 recreate listener；两者差别只在于是否追加 `_addListener` 来响应 ViewModel 自身的 `notifyListeners()`。
- 修改 `listen` 传参时必须理解 watch/read 语义差异，不可随意将 `false` 改为 `true`。
- `InstanceHandle.action` 仅在 `notifyListeners()` 回调期间有值，回调后清空为 `null`；disposed 后回退到 `_lastAction`。

## Publishing Notes

When publishing, follow `.agents/skills/publish-process/SKILL.md`.

Current expected publish order:

1. `view_model_annotation`
2. `view_model_generator`
3. `view_model`

Do not publish `view_model_devtools_extension`.
