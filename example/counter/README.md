# Counter Example

这是一个使用 `view_model` 包实现的计数器示例，展示了以下特性：

## 功能特点

1. **状态管理**
   - 使用 `StateViewModel` 管理计数器状态
   - 支持增加、减少、重置等操作
   - 可配置增量值

2. **多页面状态共享**
   - 主页面显示计数器当前状态
   - 设置页面可调整增量值
   - 通过 `ViewModelFactory` 实现状态共享

3. **响应式更新**
   - 状态变化自动触发界面更新
   - 多个页面同步响应状态变化

## 项目结构

```
lib/
  ├── main.dart              # 应用入口
  ├── counter_state.dart      # 状态定义
  ├── counter_view_model.dart # ViewModel 实现
  ├── counter_page.dart       # 主页面
  └── settings_page.dart      # 设置页面
```

## 运行方式

1. 确保已安装 Flutter SDK
2. 在项目根目录执行：
   ```bash
   flutter pub get
   flutter run
   ```

## 核心代码示例

### 状态定义
```dart
class CounterState {
  final int count;
  final int incrementBy;
  // ...
}
```

### ViewModel 实现
```dart
class CounterViewModel extends StateViewModel<CounterState> {
  void increment() {
    setState(state.copyWith(
      count: state.count + state.incrementBy,
    ));
  }
  // ...
}
```

### 状态共享
```dart
class CounterViewModelFactory with ViewModelFactory<CounterViewModel> {
  @override
  String? key() => 'shared-counter-viewmodel';
  // ...
}
```

## 学习要点

1. 如何使用 `StateViewModel` 管理状态
2. 如何实现多页面状态共享
3. 如何在 Widget 中监听和更新状态
4. 如何使用 `ViewModelFactory` 创建共享实例