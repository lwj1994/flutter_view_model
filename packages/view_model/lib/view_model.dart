/// A comprehensive ViewModel framework for Flutter applications.
///
/// This library provides a robust, scalable solution for state management
/// in Flutter applications using the ViewModel pattern. It offers automatic
/// lifecycle management, dependency tracking, and seamless integration with
/// Flutter's widget system.
///
/// ## Quick Start
///
/// - **Watch**: `watchViewModel<T>()` / `watchCachedViewModel<T>()`
/// - **Read**: `readViewModel<T>()` / `readCachedViewModel<T>()`
/// - **Global**: `ViewModel.readCached<T>()` / `ViewModel.maybeReadCached<T>()`
/// - **Recycle**: `recycleViewModel(vm)`
/// - **Effects**: `listen(onChanged)` / `listenState` / `listenStateSelect`
///
/// ## Core Features
///
/// - **Automatic Lifecycle Management**: ViewModels are automatically created,
///   cached, and disposed based on widget lifecycle.
/// - **Instance Reuse**: Share a single ViewModel instance across multiple
///   widgets using keys or tags.
/// - **Value-level Rebuilds**: Optimize performance by rebuilding only the
///   widgets that depend on specific state values.
/// - **Stateful ViewModel**: Manage immutable state with `StateViewModel<S>`
///   and update it using `setState(newState)`.
/// - **Dependency Injection**: Decouple ViewModels from widgets and from
///   each other.
/// - **DevTools Extension**: Monitor and debug ViewModels in real-time with
///   the Flutter DevTools extension.
///
/// ## Basic Usage
///
/// ```dart
/// // 1. Create a ViewModel
/// class CounterViewModel extends ViewModel {
///   int _counter = 0;
///   int get counter => _counter;
///
///   void increment() {
///     update(() {
///       _counter++;
///     });
///   }
/// }
///
/// // 2. Create a factory
/// class CounterFactory with ViewModelFactory<CounterViewModel> {
///   @override
///   CounterViewModel build() => CounterViewModel();
/// }
///
/// // 3. Use in a widget
/// class CounterWidget extends StatefulWidget {
///   @override
///   _CounterWidgetState createState() => _CounterWidgetState();
/// }
///
/// class _CounterWidgetState extends State<CounterWidget>
///                       with ViewModelStateMixin {
///   late final counterVM = watchViewModel<CounterViewModel>(factory:
///                                                          CounterFactory());
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         Text('Count: ${counterVM.counter}'),
///         ElevatedButton(
///           onPressed: counterVM.increment,
///           child: Text('Increment'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
library;

export "package:view_model/src/get_instance/store.dart" show InstanceArg;
export "package:view_model/src/view_model/binder.dart";
export "package:view_model/src/view_model/builder.dart";
export "package:view_model/src/view_model/config.dart";
export "package:view_model/src/view_model/pause_provider.dart";
export "package:view_model/src/view_model/value_observer.dart";
export "package:view_model/src/view_model/value_watcher.dart";
export "package:view_model/src/view_model/view_model.dart";
export "package:view_model/src/view_model/widget_mixin/stateful_extension.dart";
export "package:view_model/src/view_model/widget_mixin/stateless_extension.dart";
