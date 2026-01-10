import 'package:view_model/src/view_model/view_model.dart';

/// A simple, argument-less specification for creating a ViewModel.
/// Provides builder and optional cache identifiers (`key` and `tag`).
/// Set `isSingleton` to reuse the same instance for identical `key`+`tag`.
class ViewModelProvider<T extends ViewModel> extends ViewModelFactory<T> {
  final T Function() builder;
  late final Object? _key;
  late final Object? _tag;
  final bool isSingleton;
  final bool _aliveForever;
  ViewModelProvider<T>? _proxy;

  ViewModelProvider({
    required this.builder,
    Object? key,
    Object? tag,

    /// Whether to use singleton mode. This is just a convenient way to
    /// set a unique key for you.
    /// Note that the priority is lower than the key parameter.
    @Deprecated('Use key instead') this.isSingleton = false,

    /// Whether the instance should live forever (never be disposed).
    bool aliveForever = false,
  }) : _aliveForever = aliveForever {
    _key = key;
    _tag = tag;
  }

  /// Enables test-time override of factory properties.
  /// When set, overrides `builder`, `key`, `tag`, and `isSingleton`.
  void setProxy(ViewModelProvider<T> provider) {
    this._proxy = provider;
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

  /// Creates an arg-based provider with one argument.
  ///
  /// Use this to declare builder and sharing rules derived from `A`.
  static ViewModelProviderWithArg<VM, A> arg<VM extends ViewModel, A>({
    required VM Function(A a) builder,
    Object? Function(A a)? key,
    Object? Function(A a)? tag,
    @Deprecated('Use key instead') bool Function(A a)? isSingleton,
    // defaults to false
    bool Function(A a)? aliveForever,
  }) {
    return ViewModelProviderWithArg<VM, A>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based provider with two arguments.
  static ViewModelProviderWithArg2<VM, A, B> arg2<VM extends ViewModel, A, B>({
    required VM Function(A a, B b) builder,
    Object? Function(A a, B b)? key,
    Object? Function(A a, B b)? tag,
    @Deprecated('Use key instead') bool Function(A a, B b)? isSingleton,
    bool Function(A a, B b)? aliveForever,
  }) {
    return ViewModelProviderWithArg2<VM, A, B>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based provider with three arguments.
  static ViewModelProviderWithArg3<VM, A, B, C>
      arg3<VM extends ViewModel, A, B, C>({
    required VM Function(A a, B b, C c) builder,
    Object? Function(A a, B b, C c)? key,
    Object? Function(A a, B b, C c)? tag,
    @Deprecated('Use key instead') bool Function(A a, B b, C c)? isSingleton,
    bool Function(A a, B b, C c)? aliveForever,
  }) {
    return ViewModelProviderWithArg3<VM, A, B, C>(
      builder: builder,
      key: key,
      tag: tag,
      // ignore: deprecated_member_use_from_same_package
      isSingleton: isSingleton,
      aliveForever: aliveForever,
    );
  }

  /// Creates an arg-based provider with four arguments.
  static ViewModelProviderWithArg4<VM, A, B, C, D>
      arg4<VM extends ViewModel, A, B, C, D>({
    required VM Function(A a, B b, C c, D d) builder,
    Object? Function(A a, B b, C c, D d)? key,
    Object? Function(A a, B b, C c, D d)? tag,
    @Deprecated('Use key instead')
    bool Function(A a, B b, C c, D d)? isSingleton,
    bool Function(A a, B b, C c, D d)? aliveForever,
  }) {
    return ViewModelProviderWithArg4<VM, A, B, C, D>(
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
/// The cache identifiers and singleton flag are computed from the argument.
class ViewModelProviderWithArg<VM extends ViewModel, A> {
  ViewModelProviderWithArg({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead') this.isSingleton,
    this.aliveForever,
  });

  /// Builder that creates `VM` from the provided argument.
  final VM Function(A argument) builder;

  /// Computes a cache key from argument (optional).
  final Object? Function(A argument)? key;

  /// Computes a cache tag from argument (optional).
  final Object? Function(A argument)? tag;

  /// Determines if the instance should be singleton for the given arg.
  @Deprecated('Use key instead')
  final bool Function(A argument)? isSingleton;

  /// Whether the instance should live forever (never be disposed).
  final bool Function(A argument)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelProviderWithArg<VM, A>? _proxy;

  /// Enables test-time override of arg-based provider behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelProviderWithArg<VM, A> provider) {
    _proxy = provider;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  /// Converts this spec into a `ViewModelFactory` using `arg`.
  /// The factory defers building until requested by the binder.
  ViewModelFactory<VM> call(A arg) {
    final spec = _proxy ?? this;
    return ViewModelProvider<VM>(
      builder: () => spec.builder(arg),
      key: spec.key?.call(arg),
      tag: spec.tag?.call(arg),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(arg) ?? false,
      aliveForever: spec.aliveForever?.call(arg) ?? false,
    );
  }
}

class ViewModelProviderWithArg2<VM extends ViewModel, A, B> {
  ViewModelProviderWithArg2({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead') this.isSingleton,
    this.aliveForever,
  });

  final VM Function(A a, B b) builder;
  final Object? Function(A a, B b)? key;
  final Object? Function(A a, B b)? tag;
  @Deprecated('Use key instead')
  final bool Function(A a, B b)? isSingleton;
  final bool Function(A a, B b)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelProviderWithArg2<VM, A, B>? _proxy;

  /// Enables test-time override of arg-based provider behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelProviderWithArg2<VM, A, B> provider) {
    _proxy = provider;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  ViewModelFactory<VM> call(A a, B b) {
    final spec = _proxy ?? this;
    return ViewModelProvider<VM>(
      builder: () => spec.builder(a, b),
      key: spec.key?.call(a, b),
      tag: spec.tag?.call(a, b),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(a, b) ?? false,
      aliveForever: spec.aliveForever?.call(a, b) ?? false,
    );
  }
}

class ViewModelProviderWithArg3<VM extends ViewModel, A, B, C> {
  ViewModelProviderWithArg3({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead') this.isSingleton,
    this.aliveForever,
  });

  final VM Function(A a, B b, C c) builder;
  final Object? Function(A a, B b, C c)? key;
  final Object? Function(A a, B b, C c)? tag;
  @Deprecated('Use key instead')
  final bool Function(A a, B b, C c)? isSingleton;
  final bool Function(A a, B b, C c)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelProviderWithArg3<VM, A, B, C>? _proxy;

  /// Enables test-time override of arg-based provider behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelProviderWithArg3<VM, A, B, C> provider) {
    _proxy = provider;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  ViewModelFactory<VM> call(A a, B b, C c) {
    final spec = _proxy ?? this;
    return ViewModelProvider<VM>(
      builder: () => spec.builder(a, b, c),
      key: spec.key?.call(a, b, c),
      tag: spec.tag?.call(a, b, c),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(a, b, c) ?? false,
      aliveForever: spec.aliveForever?.call(a, b, c) ?? false,
    );
  }
}

class ViewModelProviderWithArg4<VM extends ViewModel, A, B, C, D> {
  ViewModelProviderWithArg4({
    required this.builder,
    this.key,
    this.tag,
    @Deprecated('Use key instead') this.isSingleton,
    this.aliveForever,
  });

  final VM Function(A a, B b, C c, D d) builder;
  final Object? Function(A a, B b, C c, D d)? key;
  final Object? Function(A a, B b, C c, D d)? tag;
  @Deprecated('Use key instead')
  final bool Function(A a, B b, C c, D d)? isSingleton;
  final bool Function(A a, B b, C c, D d)? aliveForever;

  /// Proxy for test-time override.
  ///
  /// When set, the proxy overrides `builder`, `key`, `tag`, and
  /// `isSingleton` computations. Use `setProxy` to install and
  /// `clearProxy` to remove.
  ViewModelProviderWithArg4<VM, A, B, C, D>? _proxy;

  /// Enables test-time override of arg-based provider behavior.
  ///
  /// Replaces this spec with values from the provided proxy when calling.
  void setProxy(ViewModelProviderWithArg4<VM, A, B, C, D> provider) {
    _proxy = provider;
  }

  /// Clears any proxy overrides and restores original behavior.
  void clearProxy() {
    _proxy = null;
  }

  ViewModelFactory<VM> call(A a, B b, C c, D d) {
    final spec = _proxy ?? this;
    return ViewModelProvider<VM>(
      builder: () => spec.builder(a, b, c, d),
      key: spec.key?.call(a, b, c, d),
      tag: spec.tag?.call(a, b, c, d),
      // ignore: deprecated_member_use_from_same_package
      isSingleton: spec.isSingleton?.call(a, b, c, d) ?? false,
      aliveForever: spec.aliveForever?.call(a, b, c, d) ?? false,
    );
  }
}
