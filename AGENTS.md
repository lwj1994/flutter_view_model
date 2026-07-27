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

## ViewModel Test Rules

- ViewModel tests must run single-threaded and in declaration/runner order.
  The runtime registry, configuration, lifecycle observers, and legacy spec
  proxies are process-global mutable state; do not enable parallel test files,
  test sharding, or concurrent groups. Use `zsh -ic 'ff test --concurrency=1'`.
- Never instantiate a ViewModel directly in a test body or `setUp` callback.
  Put constructor calls inside a `ViewModelSpec`/factory builder and resolve the
  instance through a `ViewModelBinding` with `read` or `watch`.
- Do not retain ViewModels in `late`/`final` test fields. Expose them through a
  getter that resolves via the test binding, and dispose that binding in
  `tearDown` or `addTearDown`.

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

#### 推荐的 spec-based 解析

| 方法 | 创建实例 | bind | addRef | ViewModel listener | recreate listener |
|------|---------|------|--------|-------------------|------------------|
| `watch(factory)` | 是 | 是 | 是 | 是（root 更新 / parent 冒泡） | 是 |
| `read(factory)` | 是 | 是 | 是 | 否 | 是 |

#### 高级 cached 查询（通常不推荐）

这些 API 只查询已由其他路径创建的缓存，不能替代 spec-based 依赖解析。

| 方法 | 创建实例 | bind | addRef | ViewModel listener | recreate listener |
|------|---------|------|--------|-------------------|------------------|
| `watchCached(key/tag)` | 否 | 是 | 是 | 是 | 是 |
| `maybeWatchCached(key/tag)` | 否 | 命中时是 | 命中时是 | 命中时是 | 命中时是 |
| `readCached(key/tag)` | 否 | 是 | 是 | 否 | 是 |
| `maybeReadCached(key/tag)` | 否 | 命中时是 | 命中时是 | 否 | 命中时是 |
| `watchCachesByTag(tag)` | 否 | 是 | 是 | 是 | 是 |
| `readCachesByTag(tag)` | 否 | 是 | 是 | 否 | 是 |

关键区别：

- **watch vs read**：watch 注册 ViewModel listener（`_addListener`）；root/widget
  binding 会触发 `onUpdate`/rebuild，dependency binding 会向 parent 冒泡。read
  不响应 ViewModel 自身通知，但仍感知 handle recreate/dispose。
- **有 factory vs Cached**：有 factory 时可以创建新实例；Cached 只查找已有缓存。
- **Cached API 是高级查询入口**：正常模块依赖应保留 spec，并通过
  `watch(spec)`/`read(spec)` 解析。不要绕过 spec 去捞“恰好存在”的缓存；只有
  明确需要跨 owner 查询，并理解 cache identity、创建顺序、未命中、tag 多匹配
  与生命周期耦合时才使用 cached/maybe/tag batch API。
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
  → AutoDisposeInstanceController.getInstancesByTag(tag)
    → bind + addRef（始终执行）
    → 追加 _attachRecreateListener
  → listen=true 时追加 _addListener（仅 watchCachesByTag）
```

### AutoDisposeInstanceController.getInstance

1. 将 `viewModelBinding.id` 注入 factory arg 的 `bindingId`
2. 调用 `instanceManager.getNotifier(factory)` → `Store.getNotifier()`
   - 缓存命中：直接返回已有 handle，并添加当前 binding source
   - 缓存未命中：调用 `factory.builder()` 创建实例，包装为 `InstanceHandle`，触发 `onCreate` + `bind`
3. `addRef(viewModelBinding)` — 将 binding 加入 ViewModel 的 refHandler（依赖追踪）
4. `_attachRecreateListener(notifier)` — 在 InstanceHandle 上注册 listener，仅响应 recreate/dispose 事件

### 注意事项

- `getInstance` 内部无条件注册 recreate listener，`listen` 参数只在
  ViewModelBinding 层控制 ViewModel listener（`_addListener`）。
  `getInstancesByTag(tag)` 同样为每个命中 handle 注册 recreate listener；
  `watchCachesByTag` 与 `readCachesByTag` 的差别只在于前者会额外追加
  `_addListener` 响应 ViewModel 自身的 `notifyListeners()`。
- 修改 `listen` 传参时必须理解 watch/read 语义差异，不可随意将 `false` 改为 `true`。
- `InstanceHandle.action` 仅在 `notifyListeners()` 回调期间有值，回调后清空为 `null`；disposed 后回退到 `_lastAction`。

## Parent → Child 生命周期契约

- 每个成功创建的 parent ViewModel 对象 generation 都按需拥有一个稳定的内部
  `ViewModelDependencyBinding`。通过 parent 的 `viewModelBinding` 成功解析 child
  后，会建立 `parent → child` 保活边，因此 child 生命周期不能短于该 parent
  generation。
- parent 当前所有 external root bindings 会实时传播到已解析 child；root 后续
  bind/unbind 也必须同步。`InstanceHandle` 与 `ViewModelBindingHandler` 按 source
  区分 direct、parent 及多 parent 路径：首 source 触发 `onBind(id)`，最后 source
  才触发 `onUnbind(id)`。
- unkeyed child 使用 parent generation dependency binding 的私有 default key；
  root owner 切换不会换 key。parent 成功 recreate 后，新对象获得新的 binding/key
  与 dependency tree，不迁移旧 unkeyed child。
- `watch/read`、cached/maybeCached 与 tag batch API 命中时都建立相同的 parent
  生命周期边。只有 watch 变体冒泡 child 的 `notifyListeners()`；read 变体仍感知
  handle recreate/dispose。
- nested `aliveForever` child 必须显式 key。`aliveForever` parent 会传递性保活其
  已解析 child，直到 `recycle` 或 `ViewModel.reset()`。
- 依赖图必须无环。构造期按 construction lineage 判定 unkeyed self/indirect
  recursion，运行期在提交 owner edge 前判环；diamond graph 合法。builder、
  constructor 或 replacement builder 失败必须回滚暂存 scope，失败的 recreate
  必须保留旧对象及旧 dependency scope。
- 同步通知使用 propagation transaction 并按 binding 去重；异步 microtask/Future
  通知必须开启新事务。

## Publishing Notes

When publishing, follow `.agents/skills/publish-process/SKILL.md`.

Current expected publish order:

1. `view_model_annotation`
2. `view_model_generator`
3. `view_model`

Do not publish `view_model_devtools_extension`.
