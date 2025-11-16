import 'package:flutter/widgets.dart';
import 'package:view_model/src/view_model/extension/attacher.dart';
import 'package:view_model/src/view_model/interface.dart';
import 'package:view_model/src/view_model/view_model.dart';

/// Stateless integration for ViewModel access from widgets.
/// Provides a mixin and a custom Element that bridge ViewModel
/// changes to StatelessWidget rebuilds. Supports watching and
/// reading ViewModels with or without listening.
mixin ViewModelStatelessMixin on StatelessWidget
    implements ViewModelCreateInterface {
  _StatelessViewModelElement? _element;

  @visibleForTesting
  _StatelessViewModelElement get viewModelElement => _element!;

  /// Creates the custom Element that carries the attacher.
  /// The Element owns the `ViewModelAttacher` and connects
  /// ViewModel notifications to `markNeedsBuild` for this
  /// widget.
  @override
  StatelessElement createElement() {
    if (_element == null) {
      _element = _StatelessViewModelElement(this);
    }
    return _element!;
  }

  /// Watches a cached ViewModel and rebuilds when it changes.
  /// Finds by `key` or `tag`. Does not create new instances.
  @override
  VM watchCachedViewModel<VM extends ViewModel>({Object? key, Object? tag}) {
    return _element!._attacher.watchCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Creates or fetches a ViewModel and listens for changes.
  @override
  VM watchViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    return _element!._attacher.watchViewModel(
      factory: factory,
    );
  }

  @override
  void recycleViewModel<VM extends ViewModel>(VM viewModel) {
    _element!._attacher.recycleViewModel(viewModel);
  }

  /// Safe watch for cached ViewModel, returns `null` when not found.
  @override
  VM? maybeWatchCachedViewModel<VM extends ViewModel>(
      {Object? key, Object? tag}) {
    return _element!._attacher.maybeWatchCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Safe read for cached ViewModel, returns `null` when not found.
  @override
  VM? maybeReadCachedViewModel<VM extends ViewModel>(
      {Object? key, Object? tag}) {
    return _element!._attacher.maybeReadCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Reads a cached ViewModel without listening for changes.
  @override
  VM readCachedViewModel<VM extends ViewModel>({Object? key, Object? tag}) {
    return _element!._attacher.readCachedViewModel(
      key: key,
      tag: tag,
    );
  }

  /// Creates or fetches a ViewModel without listening for changes.
  @override
  VM readViewModel<VM extends ViewModel>(
      {required ViewModelFactory<VM> factory}) {
    return _element!._attacher.readViewModel(
      factory: factory,
    );
  }
}

/// Custom Element for `ViewModelStatelessMixin`.
/// Owns the `ViewModelAttacher` and binds its rebuild callback
/// to `markNeedsBuild`. Manages attach and dispose with element
/// lifecycle.
class _StatelessViewModelElement extends StatelessElement {
  late final ViewModelAttacher _attacher =
      ViewModelAttacher(this.markNeedsBuild);

  _StatelessViewModelElement(super.widget);

  /// Attaches the element and starts ViewModel listening.
  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _attacher.attach();
  }

  /// Disposes ViewModel listeners when the element is removed.
  @override
  void unmount() {
    super.unmount();
    _attacher.dispose();
  }
}
