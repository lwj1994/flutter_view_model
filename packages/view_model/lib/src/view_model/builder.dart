// @author luwenjie on 2025/10/27 14:17:50

import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/widget_mixin/stateful_extension.dart';
import 'package:view_model/src/view_model/view_model.dart';

/// A convenient widget that does not require mixing
/// `ViewModelStateMixin` into `State`.
///
/// Behavior: internally uses `watchViewModel`. When the `ViewModel` calls
/// `notifyListeners()`, this widget rebuilds so the UI reflects the changes.
class ViewModelBuilder<T extends ViewModel> extends StatefulWidget {
  final ViewModelFactory<T> factory;
  final Widget Function(T viewModel) builder;

  const ViewModelBuilder(
      {super.key, required this.factory, required this.builder});

  @override
  State<StatefulWidget> createState() {
    return _ViewModelState<T>();
  }
}

class _ViewModelState<T extends ViewModel> extends State<ViewModelBuilder<T>>
    with ViewModelStateMixin {
  /// Builds using the watched ViewModel and passes it to the builder.
  ///
  /// The builder does not require `BuildContext`; only the `ViewModel` is
  /// provided as an argument, matching the builder's signature.
  @override
  Widget build(BuildContext context) {
    return widget.builder.call(watchViewModel<T>(
      factory: widget.factory,
    ));
  }
}

/// Listens to and uses a `ViewModel` that already exists in the cache.
///
/// Behavior: internally uses `watchCachedViewModel`. When the `ViewModel` calls
/// `notifyListeners()`, this widget rebuilds. To avoid confusion with the
/// widget's `Key`, use `shareKey` as the `ViewModel` key parameter.
class CachedViewModelBuilder<T extends ViewModel> extends StatefulWidget {
  final Object? shareKey;
  final Object? tag;
  final Widget Function(T viewModel) builder;

  const CachedViewModelBuilder({
    super.key,
    this.shareKey,
    this.tag,
    required this.builder,
  });

  @override
  State<StatefulWidget> createState() {
    return _CachedViewModelState<T>();
  }
}

class _CachedViewModelState<T extends ViewModel>
    extends State<CachedViewModelBuilder<T>> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = maybeWatchCachedViewModel<T>(
      key: widget.shareKey,
      tag: widget.tag,
    );
    if (vm == null) return const SizedBox.shrink();
    return widget.builder.call(
      vm,
    );
  }
}
