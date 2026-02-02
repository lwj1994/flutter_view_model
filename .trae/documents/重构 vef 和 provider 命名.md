# 重构设计方案 v12：Spec & Binding (兼容性过渡)

遵循您的指示，我们将采用 **平滑过渡** 策略：引入新概念的同时，保留旧概念并标记为 `@Deprecated`，确保现有代码不报错。

## 1. Provider -> ViewModelSpec (主推)

*   **实现方式**:
    1.  将核心逻辑类重命名为 **`ViewModelSpec`**。
    2.  保留 **`ViewModelProvider`** 类，标记为 `@Deprecated`，并使其继承自 `ViewModelSpec`。
    3.  在 `ViewModelProvider` 中重新桥接静态方法（如 `.arg`），以确保旧代码的 `ViewModelProvider.arg(...)` 依然可用。

## 2. Vef -> ViewModelBinding (主推)

*   **实现方式**:
    1.  将核心逻辑类重命名为 **`ViewModelBinding`**。
    2.  保留 **`Vef`** 类，标记为 `@Deprecated`，并通过 `mixin` 方式复用 `ViewModelBinding` 的逻辑。
    3.  在 Widget Mixin 中，新增 **`viewModelBinding`** 属性。
    4.  保留 **`vef`** 属性，标记为 `@Deprecated`，指向 `viewModelBinding`。

## 3. 文件处理

*   **创建新文件**: `view_model_spec.dart` 和 `view_model_binding.dart`，存放新的核心逻辑。
*   **保留旧文件**: `provider.dart` 和 `vef.dart` 保留（或作为转发文件），导出新文件并包含 Deprecated 的兼容类。

## 4. 最终效果

### 新代码 (推荐)
```dart
final mySpec = ViewModelSpec(builder: () => MyVM());
// ...
viewModelBinding.watch(mySpec);
```

### 旧代码 (兼容，但会有删除线提示)
```dart
final myProvider = ViewModelProvider(builder: () => MyVM()); // Warning
// ...
vef.watch(myProvider); // Warning
```

## 执行计划

1.  **Spec 重构**:
    *   创建 `view_model_spec.dart` (原 Provider 逻辑)。
    *   修改 `provider.dart`: 引入 Spec，定义兼容类 `ViewModelProvider`。
2.  **Binding 重构**:
    *   创建 `view_model_binding.dart` (原 Vef 逻辑)。
    *   修改 `vef.dart`: 引入 Binding，定义兼容类 `Vef`。
3.  **Mixin 更新**:
    *   新增 `viewModelBinding` 属性。
    *   Deprecate `vef` 属性。
4.  **文档更新**: 更新注释和 README，推荐使用新名称。
