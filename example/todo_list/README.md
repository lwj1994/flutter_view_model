# Todo List Example

这是一个使用 `view_model` 的待办示例，演示以下能力：

1. `StateViewModel` 的列表状态管理
2. 跨页面共享同一个 ViewModel 实例（列表、搜索、统计页面）
3. 增删改查 + 分类 + 搜索 + 统计

## 项目结构

```text
lib/
  main.dart
  todo_view_model.dart
  todo_state.dart
  todo_page.dart
  search_page.dart
  stats_page.dart
```

## 运行方式

在仓库根目录执行：

```bash
cd example/todo_list
flutter pub get
flutter run
```
