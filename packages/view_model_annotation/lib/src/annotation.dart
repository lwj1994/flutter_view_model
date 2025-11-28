/// Annotation to mark a ViewModel for provider code generation.
/// Each annotated class will receive a generated `ViewModelProvider`
/// variable in a `.vm.dart` part file.
///
/// Can only be used on classes.
class GenProvider {
  /// Create a `GenProvider` annotation instance.
  const GenProvider();
}

/// Shorthand constant for `GenProvider`.
const GenProvider genProvider = GenProvider();
