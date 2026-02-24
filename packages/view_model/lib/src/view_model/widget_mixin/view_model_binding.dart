import 'package:view_model/src/view_model/view_model_binding.dart';

/// A specialized ViewModelBinding implementation for Flutter Widgets.
///
/// This class extends the base [ViewModelBinding]
/// functionality to integrate with
/// Flutter's widget lifecycle. It bridges ViewModel state changes to widget
/// rebuilds by calling the provided [refreshWidget] callback.
///
/// The [WidgetViewModelBinding] is used internally by [ViewModelStateMixin] and
/// [ViewModelStatelessMixin] to manage ViewModel lifecycles within widgets.
///
/// Key responsibilities:
/// - Triggers widget rebuilds when ViewModels notify changes via [onUpdate]
/// - Handles pause/resume lifecycle inherited from [ViewModelBinding]
/// - Manages ViewModel disposal when the widget is disposed
///
/// Example usage (typically handled internally by mixins):
/// ```dart
/// final binding = WidgetViewModelBinding(
///   refreshWidget: () => setState(() {}),
/// );
/// ```
class WidgetViewModelBinding with ViewModelBinding {
  /// Callback function to trigger widget rebuild.
  ///
  /// This is typically a reference to the widget's `setState` method or
  /// equivalent rebuild mechanism.
  final Function() refreshWidget;

  WidgetViewModelBinding({
    required this.refreshWidget,
  });

  @override
  void onUpdate() {
    super.onUpdate();
    refreshWidget();
  }
}
