import 'package:view_model/src/view_model/view_model.dart';

/// Interface that exposes helpers to access ViewModels from widgets.
///
/// Provides methods to create or fetch ViewModels, optionally listening
/// to their changes to rebuild the widget. All methods are generic on
/// `VM extends ViewModel`.
abstract interface class ViewModelCreateInterface {
  /// Creates or fetches a `VM` and listens for its changes.
  ///
  /// Requires a `factory` to build the instance when absent. The widget
  /// will rebuild whenever the ViewModel notifies its listeners.
  VM watchViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  });

  /// Fetches an existing `VM` by `key` or `tag` and listens for changes.
  ///
  /// Does not create new instances. The widget will rebuild when the
  /// ViewModel notifies listeners.
  VM watchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Creates or fetches a `VM` without listening for changes.
  ///
  /// Use this to call methods or read properties without triggering a
  /// widget rebuild.
  VM readViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  });

  /// Reads an existing `VM` by `key` or `tag` without listening.
  ///
  /// Does not create new instances and does not cause the widget to
  /// rebuild when the ViewModel changes.
  VM readCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Safe version of `watchCachedViewModel` that returns `null` when not
  /// found.
  ///
  /// Useful when a ViewModel might be optional and absence should not
  /// throw.
  VM? maybeWatchCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  /// Safe version of `readCachedViewModel` that returns `null` when not
  /// found.
  ///
  /// Reads the cached ViewModel without listening and avoids throwing
  /// when the instance does not exist.
  VM? maybeReadCachedViewModel<VM extends ViewModel>({
    Object? key,
    Object? tag,
  });

  void recycleViewModel<VM extends ViewModel>(VM viewModel);
}
