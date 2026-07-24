import 'dart:async';

import 'package:view_model/src/view_model/view_model.dart';

class _ViewModelSpecOverride<S> {
  _ViewModelSpecOverride(this.spec);

  final S spec;
}

class _ViewModelSpecOverrideContext<S> {
  _ViewModelSpecOverrideContext({this.parent});

  final _ViewModelSpecOverrideContext<S>? parent;
  final List<_ViewModelSpecOverride<S>> overrides = [];

  S? get activeProxy =>
      overrides.isEmpty ? parent?.activeProxy : overrides.last.spec;
}

mixin _ViewModelSpecProxy<S> {
  S? _proxy;
  final Object _overrideZoneKey = Object();
  final Map<Zone, _ViewModelSpecOverrideContext<S>> _zoneContexts =
      Map.identity();

  _ViewModelSpecOverrideContext<S>? _nearestManualContext([Zone? zone]) {
    var current = zone ?? Zone.current;
    while (true) {
      final context = _zoneContexts[current];
      if (context != null) return context;
      final parent = current.parent;
      if (parent == null) return null;
      current = parent;
    }
  }

  _ViewModelSpecOverrideContext<S>? get _activeOverrideContext {
    final zoned = Zone.current[_overrideZoneKey];
    if (zoned is _ViewModelSpecOverrideContext<S>) return zoned;
    return _nearestManualContext();
  }

  S? get _activeProxy => _activeOverrideContext?.activeProxy ?? _proxy;

  /// Installs the legacy global proxy used when no scoped override is active.
  void setProxy(S spec) {
    _proxy = spec;
  }

  /// Clears the legacy global proxy without disturbing scoped overrides.
  void clearProxy() {
    _proxy = null;
  }

  /// Overrides this spec until the returned restore callback is invoked.
  ///
  /// Restore callbacks are idempotent. Nested overrides restore the previous
  /// active override, and may also be restored out of order without reviving
  /// an override that has already been removed. The override belongs to the
  /// current Zone; use [runWithOverride] for an automatically isolated async
  /// scope.
  void Function() overrideWith(S spec) {
    final zone = Zone.current;
    final zoned = zone[_overrideZoneKey];
    final isRunScoped = zoned is _ViewModelSpecOverrideContext<S>;
    final context = isRunScoped
        ? zoned
        : _zoneContexts.putIfAbsent(
            zone,
            () => _ViewModelSpecOverrideContext<S>(
              parent: _nearestManualContext(zone.parent),
            ),
          );
    final entry = _ViewModelSpecOverride(spec);
    context.overrides.add(entry);
    var restored = false;

    return () {
      if (restored) {
        return;
      }
      restored = true;
      context.overrides.remove(entry);
      if (!isRunScoped &&
          context.overrides.isEmpty &&
          identical(_zoneContexts[zone], context)) {
        _zoneContexts.remove(zone);
      }
    };
  }

  /// Runs [body] with [spec] installed, then always restores the prior proxy.
  ///
  /// The prior proxy is restored when [body] completes, including when its
  /// returned future completes with an error. Each invocation uses an isolated
  /// async Zone, so overlapping bodies do not observe one another's scoped
  /// override selection. Normal key-based ViewModel instance sharing still
  /// applies after a factory has been selected.
  Future<R> runWithOverride<R>(S spec, FutureOr<R> Function() body) {
    final context = _ViewModelSpecOverrideContext<S>(
      parent: _activeOverrideContext,
    );
    final entry = _ViewModelSpecOverride(spec);
    context.overrides.add(entry);

    return runZoned<Future<R>>(
      () async {
        try {
          return await body();
        } finally {
          context.overrides.remove(entry);
        }
      },
      zoneValues: {_overrideZoneKey: context},
    );
  }
}

/// A simple, argument-less specification for creating a ViewModel.
/// Provides a builder, an optional instance `key`, and an optional grouping
/// `tag`.
/// Equal non-null [key] values reuse one instance for the same resolved generic
/// ViewModel type `T`; [tag] is only a grouping and lookup label.
class ViewModelSpec<T extends ViewModel> extends ViewModelFactory<T>
    with _ViewModelSpecProxy<ViewModelSpec<T>> {
  final T Function() builder;
  late final Object? _key;
  late final Object? _tag;
  final bool _aliveForever;
  final Object? _debugSource;

  ViewModelSpec({
    required this.builder,
    Object? key,
    Object? tag,
    Object? debugSource,

    /// Whether the instance remains alive when no bindings remain.
    /// A deliberate force recycle through `recycle` still disposes it.
    bool aliveForever = false,
  })  : _aliveForever = aliveForever,
        _debugSource = debugSource {
    _key = key;
    _tag = tag;
  }

  @override
  Object get debugSource => _debugSource ?? this;

  @override
  Object? key() {
    final proxy = _activeProxy;
    if (proxy != null) {
      return proxy.key();
    }

    if (_key == null) {
      return super.key();
    } else {
      return _key;
    }
  }

  @override
  Object? tag() {
    final proxy = _activeProxy;
    if (proxy != null) {
      return proxy.tag();
    }
    return _tag;
  }

  @override
  T build() {
    final proxy = _activeProxy;
    if (proxy != null) {
      return proxy.build();
    }
    return builder();
  }

  @override
  bool aliveForever() {
    final proxy = _activeProxy;
    if (proxy != null) {
      return proxy.aliveForever();
    }
    return _aliveForever;
  }

  /// Creates an arg-based spec with one argument.
  ///
  /// Use this to declare builder and sharing rules derived from `A`.
  static ViewModelSpecWithArg<VM, A> arg<VM extends ViewModel, A>({
    required VM Function(A a) builder,
    Object? Function(A a)? key,
    Object? Function(A a)? tag,
    // defaults to false
    bool Function(A a)? aliveForever,
  }) {
    return ViewModelSpecWithArg<VM, A>(
      builder: builder,
      key: key,
      tag: tag,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based spec with two arguments.
  static ViewModelSpecWithArg2<VM, A, B> arg2<VM extends ViewModel, A, B>({
    required VM Function(A a, B b) builder,
    Object? Function(A a, B b)? key,
    Object? Function(A a, B b)? tag,
    bool Function(A a, B b)? aliveForever,
  }) {
    return ViewModelSpecWithArg2<VM, A, B>(
      builder: builder,
      key: key,
      tag: tag,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based spec with three arguments.
  static ViewModelSpecWithArg3<VM, A, B, C>
      arg3<VM extends ViewModel, A, B, C>({
    required VM Function(A a, B b, C c) builder,
    Object? Function(A a, B b, C c)? key,
    Object? Function(A a, B b, C c)? tag,
    bool Function(A a, B b, C c)? aliveForever,
  }) {
    return ViewModelSpecWithArg3<VM, A, B, C>(
      builder: builder,
      key: key,
      tag: tag,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based spec with four arguments.
  static ViewModelSpecWithArg4<VM, A, B, C, D>
      arg4<VM extends ViewModel, A, B, C, D>({
    required VM Function(A a, B b, C c, D d) builder,
    Object? Function(A a, B b, C c, D d)? key,
    Object? Function(A a, B b, C c, D d)? tag,
    bool Function(A a, B b, C c, D d)? aliveForever,
  }) {
    return ViewModelSpecWithArg4<VM, A, B, C, D>(
      builder: builder,
      key: key,
      tag: tag,
      aliveForever: aliveForever,
    );
  }
}

/// A specification for creating a `ViewModel` from an argument.
/// The cache identifiers are computed from the argument.
class ViewModelSpecWithArg<VM extends ViewModel, A>
    with _ViewModelSpecProxy<ViewModelSpecWithArg<VM, A>> {
  ViewModelSpecWithArg({
    required this.builder,
    this.key,
    this.tag,
    this.aliveForever,
  });

  /// Builder that creates `VM` from the provided argument.
  final VM Function(A argument) builder;

  /// Computes a cache key from argument (optional).
  final Object? Function(A argument)? key;

  /// Computes a cache tag from argument (optional).
  final Object? Function(A argument)? tag;

  /// Whether the instance remains alive when no bindings remain.
  /// A deliberate force recycle through `recycle` still disposes it.
  final bool Function(A argument)? aliveForever;

  /// Converts this spec into a `ViewModelFactory` using `arg`.
  /// The factory defers building until requested by the binder.
  ViewModelFactory<VM> call(A arg) {
    final spec = _activeProxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(arg),
      key: spec.key?.call(arg),
      tag: spec.tag?.call(arg),
      aliveForever: spec.aliveForever?.call(arg) ?? false,
      debugSource: this,
    );
  }
}

class ViewModelSpecWithArg2<VM extends ViewModel, A, B>
    with _ViewModelSpecProxy<ViewModelSpecWithArg2<VM, A, B>> {
  ViewModelSpecWithArg2({
    required this.builder,
    this.key,
    this.tag,
    this.aliveForever,
  });

  final VM Function(A a, B b) builder;
  final Object? Function(A a, B b)? key;
  final Object? Function(A a, B b)? tag;
  final bool Function(A a, B b)? aliveForever;

  ViewModelFactory<VM> call(A a, B b) {
    final spec = _activeProxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(a, b),
      key: spec.key?.call(a, b),
      tag: spec.tag?.call(a, b),
      aliveForever: spec.aliveForever?.call(a, b) ?? false,
      debugSource: this,
    );
  }
}

class ViewModelSpecWithArg3<VM extends ViewModel, A, B, C>
    with _ViewModelSpecProxy<ViewModelSpecWithArg3<VM, A, B, C>> {
  ViewModelSpecWithArg3({
    required this.builder,
    this.key,
    this.tag,
    this.aliveForever,
  });

  final VM Function(A a, B b, C c) builder;
  final Object? Function(A a, B b, C c)? key;
  final Object? Function(A a, B b, C c)? tag;
  final bool Function(A a, B b, C c)? aliveForever;

  ViewModelFactory<VM> call(A a, B b, C c) {
    final spec = _activeProxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(a, b, c),
      key: spec.key?.call(a, b, c),
      tag: spec.tag?.call(a, b, c),
      aliveForever: spec.aliveForever?.call(a, b, c) ?? false,
      debugSource: this,
    );
  }
}

class ViewModelSpecWithArg4<VM extends ViewModel, A, B, C, D>
    with _ViewModelSpecProxy<ViewModelSpecWithArg4<VM, A, B, C, D>> {
  ViewModelSpecWithArg4({
    required this.builder,
    this.key,
    this.tag,
    this.aliveForever,
  });

  final VM Function(A a, B b, C c, D d) builder;
  final Object? Function(A a, B b, C c, D d)? key;
  final Object? Function(A a, B b, C c, D d)? tag;
  final bool Function(A a, B b, C c, D d)? aliveForever;

  ViewModelFactory<VM> call(A a, B b, C c, D d) {
    final spec = _activeProxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(a, b, c, d),
      key: spec.key?.call(a, b, c, d),
      tag: spec.tag?.call(a, b, c, d),
      aliveForever: spec.aliveForever?.call(a, b, c, d) ?? false,
      debugSource: this,
    );
  }
}

/// (Deprecated) Use [ViewModelSpec] instead.
@Deprecated('Use ViewModelSpec instead.')
class ViewModelProvider<T extends ViewModel> extends ViewModelSpec<T> {
  ViewModelProvider({
    required super.builder,
    super.key,
    super.tag,
    super.aliveForever,
  });
}
