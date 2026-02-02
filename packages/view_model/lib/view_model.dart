/// A comprehensive ViewModel framework for Flutter applications.
///
/// This library provides a robust, scalable solution for state management
/// in Flutter applications using the ViewModel pattern. It offers automatic
/// lifecycle management, dependency tracking, and seamless integration with
/// Flutter's widget system.
///
/// ## Quick Start
///
/// ```dart
/// // 1. Define a ViewModel
/// class CounterViewModel extends ViewModel {
///   int count = 0;
///   void increment() => update(() => count++);
/// }
///
/// // 2. Create a Spec
/// final counterSpec = ViewModelSpec<CounterViewModel>(
///   builder: () => CounterViewModel(),
/// );
///
/// // 3. Use in a Widget
/// class CounterPage extends StatefulWidget {
///   @override
///   State<CounterPage> createState() => _CounterPageState();
/// }
///
/// class _CounterPageState extends State<CounterPage>
///     with ViewModelStateMixin {
///   @override
///   Widget build(BuildContext context) {
///     final vm = viewModelBinding.watch(counterSpec);
///     return ElevatedButton(
///       onPressed: vm.increment,
///       child: Text('Count: ${vm.count}'),
///     );
///   }
/// }
/// ```
///
/// ## The `viewModelBinding` Accessor
///
/// `viewModelBinding` (ViewModel Execution Framework) is your gateway to ViewModels:
///
/// | Method | Description |
/// |--------|-------------|
/// | `viewModelBinding.watch(spec)` | Get VM and rebuild on changes |
/// | `viewModelBinding.read(spec)` | Get VM without rebuilding |
/// | `viewModelBinding.watchCached<T>(key:)` | Get cached VM by key with rebuilds |
/// | `viewModelBinding.readCached<T>(key:)` | Get cached VM by key, no rebuilds |
/// | `viewModelBinding.listen(spec, onChanged:)` | Side effects, auto-disposed |
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
library;

export "package:view_model/src/get_instance/store.dart" show InstanceArg;
export "package:view_model/src/view_model/view_model_binding.dart";
export "package:view_model/src/view_model/builder.dart";
export "package:view_model/src/view_model/config.dart";
export "package:view_model/src/view_model/view_model_spec.dart";
export "package:view_model/src/view_model/pause_provider.dart";

export "package:view_model/src/view_model/value_observer.dart";
export "package:view_model/src/view_model/value_watcher.dart";
export "package:view_model/src/view_model/view_model.dart";
export "package:view_model/src/view_model/widget_mixin/stateful_extension.dart";
export "package:view_model/src/view_model/widget_mixin/stateless_extension.dart";
export "package:view_model_annotation/view_model_annotation.dart";
