import 'package:view_model/src/view_model/view_model.dart';

/// A simple, argument-less specification for creating a ViewModel.
/// Provides builder and optional cache identifiers (`key` and `tag`).
/// Set `isSingleton` to reuse the same instance for identical `key`+`tag`.
class ViewModelProvider<T extends ViewModel> extends ViewModelFactory<T> {
  final T Function() builder;
  late final Object? _key;
  late final Object? _tag;
  final bool isSingleton;

  ViewModelProvider({
    required this.builder,
    Object? key,
    Object? tag,

    /// Whether to use singleton mode. This is just a convenient way to
    /// set a unique key for you.
    /// Note that the priority is lower than the key parameter.
    this.isSingleton = false,
  }) {
    _key = key;
    _tag = tag;
  }

  @override
  Object? key() {
    if (_key == null) {
      return super.key();
    } else {
      return _key;
    }
  }

  @override
  Object? tag() => _tag;

  @override
  T build() => builder();

  @override
  bool singleton() => isSingleton;

  /// Creates an arg-based provider with one argument.
  ///
  /// Use this to declare builder and sharing rules derived from `A`.
  static ViewModelProviderWithArg<VM, A> arg<VM extends ViewModel, A>({
    required VM Function(A a) builder,
    Object? Function(A a)? key,
    Object? Function(A a)? tag,
    bool Function(A a)? isSingleton,
  }) {
    return ViewModelProviderWithArg<VM, A>(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
    );
  }

  /// Creates an arg-based provider with two arguments.
  static ViewModelProviderWithArg2<VM, A, B> arg2<VM extends ViewModel, A, B>({
    required VM Function(A a, B b) builder,
    Object? Function(A a, B b)? key,
    Object? Function(A a, B b)? tag,
    bool Function(A a, B b)? isSingleton,
  }) {
    return ViewModelProviderWithArg2<VM, A, B>(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
    );
  }

  /// Creates an arg-based provider with three arguments.
  static ViewModelProviderWithArg3<VM, A, B, C>
      arg3<VM extends ViewModel, A, B, C>({
    required VM Function(A a, B b, C c) builder,
    Object? Function(A a, B b, C c)? key,
    Object? Function(A a, B b, C c)? tag,
    bool Function(A a, B b, C c)? isSingleton,
  }) {
    return ViewModelProviderWithArg3<VM, A, B, C>(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
    );
  }

  /// Creates an arg-based provider with four arguments.
  static ViewModelProviderWithArg4<VM, A, B, C, D>
      arg4<VM extends ViewModel, A, B, C, D>({
    required VM Function(A a, B b, C c, D d) builder,
    Object? Function(A a, B b, C c, D d)? key,
    Object? Function(A a, B b, C c, D d)? tag,
    bool Function(A a, B b, C c, D d)? isSingleton,
  }) {
    return ViewModelProviderWithArg4<VM, A, B, C, D>(
      builder: builder,
      key: key,
      tag: tag,
      isSingleton: isSingleton,
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
    this.isSingleton,
  });

  /// Builder that creates `VM` from the provided argument.
  final VM Function(A argument) builder;

  /// Computes a cache key from argument (optional).
  final Object? Function(A argument)? key;

  /// Computes a cache tag from argument (optional).
  final Object? Function(A argument)? tag;

  /// Determines if the instance should be singleton for the given arg.
  final bool Function(A argument)? isSingleton;

  /// Converts this spec into a `ViewModelFactory` using `arg`.
  /// The factory defers building until requested by the binder.
  ViewModelFactory<VM> call(A arg) {
    return ViewModelProvider<VM>(
      builder: () => builder(arg),
      key: key?.call(arg),
      tag: tag?.call(arg),
      isSingleton: isSingleton?.call(arg) ?? false,
    );
  }
}

class ViewModelProviderWithArg2<VM extends ViewModel, A, B> {
  ViewModelProviderWithArg2({
    required this.builder,
    this.key,
    this.tag,
    this.isSingleton,
  });

  final VM Function(A a, B b) builder;
  final Object? Function(A a, B b)? key;
  final Object? Function(A a, B b)? tag;
  final bool Function(A a, B b)? isSingleton;

  ViewModelFactory<VM> call(A a, B b) {
    return ViewModelProvider<VM>(
      builder: () => builder(a, b),
      key: key?.call(a, b),
      tag: tag?.call(a, b),
      isSingleton: isSingleton?.call(a, b) ?? false,
    );
  }
}

class ViewModelProviderWithArg3<VM extends ViewModel, A, B, C> {
  ViewModelProviderWithArg3({
    required this.builder,
    this.key,
    this.tag,
    this.isSingleton,
  });

  final VM Function(A a, B b, C c) builder;
  final Object? Function(A a, B b, C c)? key;
  final Object? Function(A a, B b, C c)? tag;
  final bool Function(A a, B b, C c)? isSingleton;

  ViewModelFactory<VM> call(A a, B b, C c) {
    return ViewModelProvider<VM>(
      builder: () => builder(a, b, c),
      key: key?.call(a, b, c),
      tag: tag?.call(a, b, c),
      isSingleton: isSingleton?.call(a, b, c) ?? false,
    );
  }
}

class ViewModelProviderWithArg4<VM extends ViewModel, A, B, C, D> {
  ViewModelProviderWithArg4({
    required this.builder,
    this.key,
    this.tag,
    this.isSingleton,
  });

  final VM Function(A a, B b, C c, D d) builder;
  final Object? Function(A a, B b, C c, D d)? key;
  final Object? Function(A a, B b, C c, D d)? tag;
  final bool Function(A a, B b, C c, D d)? isSingleton;

  ViewModelFactory<VM> call(A a, B b, C c, D d) {
    return ViewModelProvider<VM>(
      builder: () => builder(a, b, c, d),
      key: key?.call(a, b, c, d),
      tag: tag?.call(a, b, c, d),
      isSingleton: isSingleton?.call(a, b, c, d) ?? false,
    );
  }
}
