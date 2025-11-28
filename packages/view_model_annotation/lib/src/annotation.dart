/// Annotation to mark a ViewModel for provider code generation.
/// Each annotated class will receive a generated `ViewModelProvider`
/// variable in a `.vm.dart` part file.
///
/// Can only be used on classes.
class GenProvider {
  /// Optional string templates for cache key and tag.
  /// When the generated provider has arguments, templates support
  /// using constructor parameter names via `$name` interpolation.
  /// Example: `key: 'user-$id:$page'`.
  final Object? key;
  final Object? tag;

  /// Create a `GenProvider` annotation instance.
  const GenProvider({this.key, this.tag});
}

/// Shorthand constant for `GenProvider`.
const GenProvider genProvider = GenProvider();

/// Marker type to carry a code expression string in annotations.
/// The generator will unwrap `Expr(code)` and emit `code` as an
/// expression inside builder closures, instead of a string literal.
class Expr {
  final String code;
  final bool isString;
  const Expr(this.code, {this.isString = false});
}
