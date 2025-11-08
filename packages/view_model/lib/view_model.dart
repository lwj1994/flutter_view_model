/// A comprehensive ViewModel framework for Flutter applications.
///
/// This library provides a robust, scalable solution for state management
/// in Flutter applications using the ViewModel pattern. It offers automatic
/// lifecycle management, dependency tracking, and seamless integration with
/// Flutter's widget system.
///
/// ## Key Features
///
/// - **Automatic Lifecycle Management**: ViewModels are automatically created,
///   cached, and disposed based on widget lifecycle
/// - **Dependency Tracking**: Comprehensive tracking of ViewModel dependencies
///   and relationships for debugging and optimization
/// - **State Management**: Built-in state management with change notifications
///   and previous state tracking
/// - **DevTools Integration**: Full integration with Flutter DevTools for
///   debugging and visualization
/// - **Memory Leak Prevention**: Automatic cleanup and disposal when ViewModels
///   are no longer needed
/// - **Flexible Configuration**: Customizable behavior through global
///                               configuration
///
/// ## Basic Usage
///
/// ```dart
/// // 1. Create a ViewModel
/// class CounterViewModel extends ViewModel<int> {
///   CounterViewModel() : super(0);
///
///   void increment() {
///     setState(state + 1);
///   }
/// }
///
/// // 2. Use in a widget
/// class CounterWidget extends StatefulWidget {
///   @override
///   _CounterWidgetState createState() => _CounterWidgetState();
/// }
///
/// class _CounterWidgetState extends State<CounterWidget>
///     with ViewModelStateMixin {
///   @override
///   Widget build(BuildContext context) {
///     final counter = watchViewModel<CounterViewModel>();
///
///     return Column(
///       children: [
///         Text('Count: ${counter.state}'),
///         ElevatedButton(
///           onPressed: counter.increment,
///           child: Text('Increment'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// ## Advanced Features
///
/// ### Custom Configuration
/// ```dart
/// ViewModel.config = ViewModelConfig(
///   logEnable: true,
///   isSameState: (previous, current) => previous?.id == current?.id,
/// );
/// ```
///
/// ### Instance Management
/// ```dart
/// // Create with specific key
/// final viewModel = watchViewModel<MyViewModel>(
///   factory: InstanceFactory<MyViewModel>(
///     builder: () => MyViewModel(customData),
///     arg: InstanceArg(key: 'unique_key'),
///   ),
/// );
///
/// // Force recreation
/// recycleViewModel(viewModel);
/// ```
///
/// ### DevTools Integration
/// ```dart
/// // Initialize DevTools service (usually done automatically)
/// DevToolsService.instance.initialize();
/// ```
///
/// ## Architecture
///
/// The framework consists of several key components:
///
/// - **ViewModel**: Base class for all ViewModels with state management
/// - **ViewModelStateMixin**: Mixin for widgets to integrate with ViewModels
/// - **InstanceManager**: Manages ViewModel instance lifecycle
/// - **DependencyTracker**: Tracks relationships between ViewModels and widgets
/// - **DevToolsService**: Provides debugging integration with Flutter DevTools
///
/// ## Best Practices
///
/// 1. **Single Responsibility**: Keep ViewModels focused on specific
///                               functionality
/// 2. **Immutable State**: Use immutable state objects when possible
/// 3. **Proper Disposal**: Let the framework handle disposal automatically
/// 4. **Testing**: ViewModels can be easily unit tested in isolation
/// 5. **Performance**: Use keys and tags for efficient instance management
///
/// For more detailed documentation and examples, visit the project repository.
library;

export "package:view_model/src/get_instance/store.dart" show InstanceArg;
export "package:view_model/src/observer/value_observer.dart";
export "package:view_model/src/view_model/config.dart";
export "package:view_model/src/view_model/extension.dart";
export "package:view_model/src/view_model/view_model.dart";
export "package:view_model/src/view_model/builder.dart";
