import 'package:view_model/src/view_model/binder.dart';

/// A specialized Binder implementation for Flutter Widgets.
///
/// This class extends the base [Binder] functionality to integrate with
/// Flutter's widget lifecycle. It bridges ViewModel state changes to widget
/// rebuilds by calling the provided [refreshWidget] callback.
///
/// The [WidgetBinder] is used internally by [ViewModelStateMixin] and
/// [ViewModelStatelessMixin] to manage ViewModel lifecycles within widgets.
///
/// Key responsibilities:
/// - Triggers widget rebuilds when ViewModels notify changes via [onUpdate]
/// - Handles pause/resume lifecycle inherited from [Binder]
/// - Manages ViewModel disposal when the widget is disposed
///
/// Example usage (typically handled internally by mixins):
/// ```dart
/// final binder = WidgetBinder(
///   refreshWidget: () => setState(() {}),
/// );
/// ```
class WidgetBinder with Binder {
  /// Callback function to trigger widget rebuild.
  ///
  /// This is typically a reference to the widget's `setState` method or
  /// equivalent rebuild mechanism.
  final Function() refreshWidget;

  WidgetBinder({
    required this.refreshWidget,
  });

  @override
  void onUpdate() {
    super.onUpdate();
    refreshWidget();
  }
}
