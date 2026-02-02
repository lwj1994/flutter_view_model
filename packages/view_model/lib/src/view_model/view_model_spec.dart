import 'package:view_model/src/view_model/view_model.dart';

/// A simple, argument-less specification for creating a ViewModel.
/// Provides builder and optional cache identifiers (`key` and `tag`).
/// Use [key] to reuse the same instance for
/// identical `key`+`tag`.
class ViewModelSpec<T extends ViewModel> extends ViewModelFactory<T> {
  final T Function() builder;
  late final Object? _key;
  late final Object? _tag;
  final bool isSingleton;
  final bool _aliveForever;
  ViewModelSpec<T>? _proxy;

  ViewModelSpec({
    required this.builder,
    Object? key,
    Object? tag,

    /// Whether to use singleton mode. This is just a convenient way to
    /// set a unique key for you.
    /// Note that the priority is lower than the key parameter.
    ///
    /// **DEPRECATED**: Use `key` parameter instead.
    /// - Will be removed in v1.0.0 (July 2026)
    /// - Migration: Use `key: 'YourKey'` instead of `isSingleton: true`
    /// - See DEPRECATION_PLAN.md for details
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026). '
        'Migration: isSingleton: true → key: "YourKey"')
    this.isSingleton = false,

    /// Whether the instance should live forever (never be disposed).
    bool aliveForever = false,
  }) : _aliveForever = aliveForever {
    _key = key;
    _tag = tag;
  }

  /// Enables test-time override of factory properties.
  /// When set, overrides `builder`, `key`, `tag`, and (deprecated)
  /// `isSingleton`.
  void setProxy(ViewModelSpec<T> spec) {
    this._proxy = spec;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  @override
  Object? key() {
    if (_proxy != null) {
      return _proxy?.key();
    }

    if (_key == null) {
      return super.key();
    } else {
      return _key;
    }
  }

  @override
  Object? tag() {
    if (_proxy != null) {
      return _proxy?.tag();
    }
    return _tag;
  }

  @override
  T build() {
    if (_proxy != null) {
      return _proxy!.build();
    }
    return builder();
  }

  @override
  bool singleton() {
    if (_proxy != null) {
      return _proxy!.singleton();
    }
    return isSingleton;
  }

  @override
  bool aliveForever() {
    if (_proxy != null) {
      return _proxy!.aliveForever();
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
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026). '
        'Migration: isSingleton: (a) => true → key: (a) => "key_\$a"')
    bool Function(A a)? isSingleton,
    // defaults to false
    bool Function(A a)? aliveForever,
  }) {
    return ViewModelSpecWithArg<VM, A>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based spec with two arguments.
  static ViewModelSpecWithArg2<VM, A, B> arg2<VM extends ViewModel, A, B>({
    required VM Function(A a, B b) builder,
    Object? Function(A a, B b)? key,
    Object? Function(A a, B b)? tag,
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026).')
    bool Function(A a, B b)? isSingleton,
    bool Function(A a, B b)? aliveForever,
  }) {
    return ViewModelSpecWithArg2<VM, A, B>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based spec with three arguments.
  static ViewModelSpecWithArg3<VM, A, B, C>
      arg3<VM extends ViewModel, A, B, C>({
    required VM Function(A a, B b, C c) builder,
    Object? Function(A a, B b, C c)? key,
    Object? Function(A a, B b, C c)? tag,
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026).')
    bool Function(A a, B b, C c)? isSingleton,
    bool Function(A a, B b, C c)? aliveForever,
  }) {
    return ViewModelSpecWithArg3<VM, A, B, C>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based spec with four arguments.
  static ViewModelSpecWithArg4<VM, A, B, C, D>
      arg4<VM extends ViewModel, A, B, C, D>({
    required VM Function(A a, B b, C c, D d) builder,
    Object? Function(A a, B b, C c, D d)? key,
    Object? Function(A a, B b, C c, D d)? tag,
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026).')
    bool Function(A a, B b, C c, D d)? isSingleton,
    bool Function(A a, B b, C c, D d)? aliveForever,
  }) {
    return ViewModelSpecWithArg4<VM, A, B, C, D>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }
}

/// A specification for creating a `ViewModel` from an argument.
/// The cache identifiers (and deprecated singleton flag) are computed from
/// the argument.
class ViewModelSpecWithArg<VM extends ViewModel, A> {
  ViewModelSpecWithArg({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    this.isSingleton,
    this.aliveForever,
  });

  /// Builder that creates `VM` from the provided argument.
  final VM Function(A argument) builder;

  /// Computes a cache key from argument (optional).
  final Object? Function(A argument)? key;

  /// Computes a cache tag from argument (optional).
  final Object? Function(A argument)? tag;

  /// (Deprecated) Determines if the instance should be singleton for
  /// the given arg. Use [key] instead.
  @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
  final bool Function(A argument)? isSingleton;

  /// Whether the instance should live forever (never be disposed).
  final bool Function(A argument)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// (deprecated) `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelSpecWithArg<VM, A>? _proxy;

  /// Enables test-time override of arg-based spec behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelSpecWithArg<VM, A> spec) {
    _proxy = spec;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  /// Converts this spec into a `ViewModelFactory` using `arg`.
  /// The factory defers building until requested by the binder.
  ViewModelFactory<VM> call(A arg) {
    final spec = _proxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(arg),
      key: spec.key?.call(arg),
      tag: spec.tag?.call(arg),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(arg) ?? false,
      aliveForever: spec.aliveForever?.call(arg) ?? false,
    );
  }
}

class ViewModelSpecWithArg2<VM extends ViewModel, A, B> {
  ViewModelSpecWithArg2({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    this.isSingleton,
    this.aliveForever,
  });

  final VM Function(A a, B b) builder;
  final Object? Function(A a, B b)? key;
  final Object? Function(A a, B b)? tag;

  /// (Deprecated) Determines if the instance should be singleton for
  /// the given args. Use [key] instead.
  @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
  final bool Function(A a, B b)? isSingleton;
  final bool Function(A a, B b)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// (deprecated) `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelSpecWithArg2<VM, A, B>? _proxy;

  /// Enables test-time override of arg-based spec behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelSpecWithArg2<VM, A, B> spec) {
    _proxy = spec;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  ViewModelFactory<VM> call(A a, B b) {
    final spec = _proxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(a, b),
      key: spec.key?.call(a, b),
      tag: spec.tag?.call(a, b),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(a, b) ?? false,
      aliveForever: spec.aliveForever?.call(a, b) ?? false,
    );
  }
}

class ViewModelSpecWithArg3<VM extends ViewModel, A, B, C> {
  ViewModelSpecWithArg3({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    this.isSingleton,
    this.aliveForever,
  });

  final VM Function(A a, B b, C c) builder;
  final Object? Function(A a, B b, C c)? key;
  final Object? Function(A a, B b, C c)? tag;

  /// (Deprecated) Determines if the instance should be singleton for
  /// the given args. Use [key] instead.
  @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
  final bool Function(A a, B b, C c)? isSingleton;
  final bool Function(A a, B b, C c)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// (deprecated) `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelSpecWithArg3<VM, A, B, C>? _proxy;

  /// Enables test-time override of arg-based spec behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelSpecWithArg3<VM, A, B, C> spec) {
    _proxy = spec;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  ViewModelFactory<VM> call(A a, B b, C c) {
    final spec = _proxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(a, b, c),
      key: spec.key?.call(a, b, c),
      tag: spec.tag?.call(a, b, c),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(a, b, c) ?? false,
      aliveForever: spec.aliveForever?.call(a, b, c) ?? false,
    );
  }
}

class ViewModelSpecWithArg4<VM extends ViewModel, A, B, C, D> {
  ViewModelSpecWithArg4({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    this.isSingleton,
    this.aliveForever,
  });

  final VM Function(A a, B b, C c, D d) builder;
  final Object? Function(A a, B b, C c, D d)? key;
  final Object? Function(A a, B b, C c, D d)? tag;

  /// (Deprecated) Determines if the instance should be singleton for
  /// the given args. Use [key] instead.
  @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
  final bool Function(A a, B b, C c, D d)? isSingleton;
  final bool Function(A a, B b, C c, D d)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// (deprecated) `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelSpecWithArg4<VM, A, B, C, D>? _proxy;

  /// Enables test-time override of arg-based spec behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelSpecWithArg4<VM, A, B, C, D> spec) {
    _proxy = spec;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  ViewModelFactory<VM> call(A a, B b, C c, D d) {
    final spec = _proxy ?? this;
    return ViewModelSpec<VM>(
      builder: () => spec.builder(a, b, c, d),
      key: spec.key?.call(a, b, c, d),
      tag: spec.tag?.call(a, b, c, d),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(a, b, c, d) ?? false,
      aliveForever: spec.aliveForever?.call(a, b, c, d) ?? false,
    );
  }
}

@Deprecated('Use ViewModelSpec instead.')
class ViewModelProvider<T extends ViewModel> extends ViewModelSpec<T> {
  ViewModelProvider({
    required super.builder,
    Object? key,
    Object? tag,
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026). '
        'Migration: isSingleton: true → key: "YourKey"')
    super.isSingleton = false,
    bool aliveForever = false,
  }) : super(
          key: key,
          tag: tag,
          aliveForever: aliveForever,
        );

  static ViewModelSpecWithArg<VM, A> arg<VM extends ViewModel, A>({
    required VM Function(A a) builder,
    Object? Function(A a)? key,
    Object? Function(A a)? tag,
    @Deprecated('Use key parameter instead. '
        'Will be removed in v1.0.0 (July 2026). '
        'Migration: isSingleton: (a) => true → key: (a) => "key_\$a"')
    bool Function(A a)? isSingleton,
    bool Function(A a)? aliveForever,
  }) {
    return ViewModelSpec.arg(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  static ViewModelSpecWithArg2<VM, A, B> arg2<VM extends ViewModel, A, B>({
    required VM Function(A a, B b) builder,
    Object? Function(A a, B b)? key,
    Object? Function(A a, B b)? tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    bool Function(A a, B b)? isSingleton,
    bool Function(A a, B b)? aliveForever,
  }) {
    return ViewModelSpec.arg2(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  static ViewModelSpecWithArg3<VM, A, B, C> arg3<VM extends ViewModel, A, B, C>({
    required VM Function(A a, B b, C c) builder,
    Object? Function(A a, B b, C c)? key,
    Object? Function(A a, B b, C c)? tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    bool Function(A a, B b, C c)? isSingleton,
    bool Function(A a, B b, C c)? aliveForever,
  }) {
    return ViewModelSpec.arg3(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  static ViewModelSpecWithArg4<VM, A, B, C, D>
      arg4<VM extends ViewModel, A, B, C, D>({
    required VM Function(A a, B b, C c, D d) builder,
    Object? Function(A a, B b, C c, D d)? key,
    Object? Function(A a, B b, C c, D d)? tag,
    @Deprecated('Use key instead. Will be removed in v1.0.0 (July 2026).')
    bool Function(A a, B b, C c, D d)? isSingleton,
    bool Function(A a, B b, C c, D d)? aliveForever,
  }) {
    return ViewModelSpec.arg4(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }
}
