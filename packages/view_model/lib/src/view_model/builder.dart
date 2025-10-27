// @author luwenjie on 2025/10/27 14:17:50

import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/extension.dart';
import 'package:view_model/src/view_model/view_model.dart';

/// A convenient widget that does not require mixing `ViewModelStateMixin` into `State`.
///
/// Behavior: internally uses `watchViewModel`. When the `ViewModel` calls
/// `notifyListeners()`, this widget rebuilds so the UI reflects the changes.
class ViewModelWatcher<T extends ViewModel> extends StatefulWidget {
  final ViewModelFactory<T> factory;
  final Widget Function(BuildContext context, T viewModel) builder;

  const ViewModelWatcher(
      {super.key, required this.factory, required this.builder});

  @override
  State<StatefulWidget> createState() {
    return _ViewModelWatcherState<T>();
  }
}

class _ViewModelWatcherState<T extends ViewModel>
    extends State<ViewModelWatcher<T>> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    return widget.builder.call(
        context,
        watchViewModel<T>(
          factory: widget.factory,
        ));
  }
}

/// Listens to and uses a `ViewModel` that already exists in the cache.
///
/// Behavior: internally uses `watchCachedViewModel`. When the `ViewModel` calls
/// `notifyListeners()`, this widget rebuilds. To avoid confusion with the
/// widget's `Key`, use `vmKey` as the `ViewModel` key parameter.
class CachedViewModelWatcher<T extends ViewModel> extends StatefulWidget {
  final Object? vmKey;
  final Object? tag;
  final Widget Function(BuildContext context, T viewModel) builder;

  const CachedViewModelWatcher({
    super.key,
    this.vmKey,
    this.tag,
    required this.builder,
  });

  @override
  State<StatefulWidget> createState() {
    return _CachedViewModelWatcherState<T>();
  }
}

class _CachedViewModelWatcherState<T extends ViewModel>
    extends State<CachedViewModelWatcher<T>> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = maybeWatchCachedViewModel<T>(
      key: widget.vmKey,
      tag: widget.tag,
    );
    if (vm == null) return const SizedBox.shrink();
    return widget.builder.call(
      context,
      vm,
    );
  }
}
