/// Annotation to mark a ViewModel for spec code generation.
/// Each annotated class will receive a generated `ViewModelSpec`
/// variable in a `.vm.dart` part file.
///
/// Can only be used on classes.
class GenSpec {
  /// Optional string templates for cache key and tag.
  /// When the generated spec has arguments, templates support
  /// using constructor parameter names via `$name` interpolation.
  /// Example: `key: 'user-$id:$page'`.
  final Object? key;
  final Object? tag;

  /// Whether to use singleton mode. This is just a convenient way to
  /// set a unique key for you.
  /// Note that the priority is lower than the key parameter.
  ///
  /// **DEPRECATED**: Use `key` parameter instead.
  @Deprecated('Use key instead')
  final bool isSingleton;

  /// Whether the instance should live forever (never be disposed).
  final bool aliveForever;

  /// Create a `GenSpec` annotation instance.
  const GenSpec(
      {this.key,
      this.tag,
      this.isSingleton = false,
      this.aliveForever = false});
}

class GenProvider extends GenSpec {
  const GenProvider(
      {super.key,
      super.tag,
      super.isSingleton = false,
      super.aliveForever = false});
}

/// Shorthand constant for `GenSpec`.
const GenSpec genSpec = GenSpec();
const GenProvider genProvider = GenProvider();

/// Marker type to carry a code expression string in annotations.
/// The generator will unwrap `Expr(code)` and emit `code` as an
/// expression inside builder closures, instead of a string literal.
class Expression {
  final String code;
  final bool isString;
  const Expression(this.code, {this.isString = false});
}
