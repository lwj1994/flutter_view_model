// @author luwenjie on 2025/1/27 10:00:00

/// Dependency management handler for ViewModels.
///
/// This class encapsulates all dependency-related logic for ViewModels,
/// providing a clean separation of concerns and making the ViewModel class
/// more focused on its core responsibilities.
library;

import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart' show internal;
import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/config.dart';
import 'package:view_model/src/view_model/view_model_binding.dart';

import 'state_store.dart';

const _bindingKey = #view_model_binding;

/// Called when the ordered owner list of a ViewModel changes.
///
/// Only binding IDs are exposed in the snapshot so diagnostics can retain the
/// data without retaining the binding objects themselves.
typedef ViewModelOwnersChanged = void Function(
  List<String> owners,
  String? previousPrimaryOwner,
  String? primaryOwner,
);

/// Runs the given [body] in a zone with the provided [binding].
/// This makes the binding available for dependency resolution.
R runWithBinding<R>(R Function() body, ViewModelBinding binding) {
  return runZoned(body, zoneValues: {_bindingKey: binding});
}

/// Handler class responsible for managing ViewModel dependencies.
///
/// This class provides:
/// - Dependency configuration storage
/// - Dependency resolution through callbacks
/// - Clean separation of dependency logic from ViewModel core functionality
///
/// Example usage:
/// ```dart
/// class MyViewModel with ViewModel {
///   @override
///   void onCreate(InstanceArg arg) {
///     super.onCreate(arg);
///     final userService = viewModelBinding.read(UserServiceSpec());
///   }
/// }
/// ```
@internal
class ViewModelBindingHandler {
  /// Ordered owner view; source membership is the only mutable ref ledger.
  @internal
  List<ViewModelBinding> get dependencyBindings =>
      List.unmodifiable(_refSources.keys);

  /// Ownership sources for each externally visible binding.
  ///
  /// A root may own the same ViewModel directly and through one or more parent
  /// dependency edges. Identity-based source tracking lets those paths leave
  /// independently without changing the public owner list prematurely.
  final Map<ViewModelBinding, Set<Object>> _refSources = Map.identity();

  final List<ViewModelOwnersChanged> _ownerChangeListeners = [];
  int _ownerRevision = 0;

  ViewModelBindingHandler();

  /// Ordered bindings that currently own this ViewModel.
  ///
  /// [primaryOwner] is retained for inbound ownership diagnostics and Zone
  /// compatibility. Nested dependencies use the ViewModel generation's
  /// own stable dependency binding.
  @internal
  List<ViewModelBinding> get owners =>
      List<ViewModelBinding>.unmodifiable(_refSources.keys);

  /// Root/application bindings that own this ViewModel.
  ///
  /// Internal dependency bindings form parent-child lifecycle edges and are
  /// deliberately excluded so they are not propagated as if they were roots.
  @internal
  List<ViewModelBinding> get externalOwners => List.unmodifiable(
        _refSources.keys.where((binding) => !binding.isDependencyBinding),
      );

  /// Initial external owners visible while a ViewModel is being constructed.
  ///
  /// `Store` calls the builder before the resulting instance can receive its
  /// first `addRef`, so constructor/onCreate dependency access falls back to
  /// the binding carried by the current construction Zone.
  @internal
  List<ViewModelBinding> get constructionExternalOwners {
    final current = externalOwners;
    if (current.isNotEmpty) return current;
    final zoneBinding = Zone.current[_bindingKey] as ViewModelBinding?;
    if (zoneBinding == null ||
        zoneBinding.isDisposed ||
        zoneBinding.isDependencyBinding) {
      return const [];
    }
    return <ViewModelBinding>[zoneBinding];
  }

  /// The current binding used to resolve nested ViewModel dependencies.
  @internal
  ViewModelBinding? get primaryOwner => _refSources.keys.firstOrNull;

  /// Adds a diagnostics listener for owner and primary-owner changes.
  ///
  /// The returned callback removes the listener. The listener is also removed
  /// automatically when this handler is disposed.
  @internal
  void Function() addOwnerChangeListener(ViewModelOwnersChanged listener) {
    _ownerChangeListeners.add(listener);
    return () => _ownerChangeListeners.remove(listener);
  }

  /// Commits a source before publishing its owner change. The handle uses
  /// [notify] = false commits both views before lifecycle callbacks.
  @internal
  void Function()? addRef(
    ViewModelBinding ref, {
    Object? source,
    bool notify = true,
  }) {
    final previousPrimaryOwner = primaryOwner?.id;
    final sources = _refSources.putIfAbsent(ref, HashSet.identity);
    if (!sources.add(source ?? ref) || sources.length != 1) return null;
    final publish = _ownerChange(previousPrimaryOwner);
    if (notify) publish();
    return publish;
  }

  /// Whether [ref] owns this ViewModel through its own direct source.
  @internal
  bool hasDirectRef(ViewModelBinding ref) =>
      _refSources[ref]?.contains(ref) ?? false;

  @internal
  void Function()? removeRef(
    ViewModelBinding ref, {
    Object? source,
    bool notify = true,
  }) {
    final previousPrimaryOwner = primaryOwner?.id;
    final sources = _refSources[ref];
    if (sources == null || !sources.remove(source ?? ref)) return null;
    if (sources.isNotEmpty) return null;
    _refSources.remove(ref);
    final publish = _ownerChange(previousPrimaryOwner);
    if (notify) publish();
    return publish;
  }

  @internal
  void Function()? clearRefs({bool notify = true}) {
    if (_refSources.isEmpty) return null;
    final previousPrimaryOwner = primaryOwner?.id;
    _refSources.clear();
    final publish = _ownerChange(previousPrimaryOwner);
    if (notify) publish();
    return publish;
  }

  void Function() _ownerChange(String? previousPrimaryOwner) {
    final revision = ++_ownerRevision;
    return () {
      // A lifecycle callback may have released/rebound owners already. Never
      // publish an older snapshot after that newer ownership transition.
      if (revision == _ownerRevision) {
        _notifyOwnerChanges(previousPrimaryOwner, revision);
      }
    };
  }

  void dispose() {
    clearRefs();
    _ownerChangeListeners.clear();
  }

  ViewModelBinding get binding {
    final r =
        (primaryOwner ?? (Zone.current[_bindingKey] as ViewModelBinding?));
    if (r == null) {
      throw ViewModelError(
        'No binding available. ViewModel must be '
        'used within a ViewModelBinding context',
      );
    }
    return r;
  }

  void _notifyOwnerChanges(String? previousPrimaryOwner, int revision) {
    if (_ownerChangeListeners.isEmpty) return;
    final ownerIds = List<String>.unmodifiable(
      _refSources.keys.map((binding) => binding.id),
    );
    final currentPrimaryOwner = primaryOwner?.id;
    for (final listener in List<ViewModelOwnersChanged>.of(
      _ownerChangeListeners,
    )) {
      if (revision != _ownerRevision) break;
      if (!_ownerChangeListeners.contains(listener)) continue;
      try {
        listener(ownerIds, previousPrimaryOwner, currentPrimaryOwner);
      } catch (error, stack) {
        reportViewModelError(
          error,
          stack,
          ErrorType.listener,
          'ViewModel owner diagnostics listener error',
        );
      }
    }
  }
}
