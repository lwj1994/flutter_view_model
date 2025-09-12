import 'view_model.dart';

/// Configuration for a ViewModel dependency.
///
/// This class stores the configuration needed to create or retrieve
/// a ViewModel dependency, including key, tag, and factory.
class ViewModelDependencyConfig<T extends ViewModel> {
  final ViewModelConfig<T> config;

  /// Creates a new dependency configuration.
  const ViewModelDependencyConfig({
    required this.config,
  });
}

class ViewModelConfig<T extends ViewModel> {
  /// Optional key to identify a specific ViewModel instance
  final String? key;

  /// Optional tag for ViewModel lookup
  final Object? tag;

  /// Optional factory for creating the ViewModel if it doesn't exist
  final ViewModelFactory<T>? factory;

  /// Creates a new dependency configuration.
  const ViewModelConfig({
    this.key,
    this.tag,
    this.factory,
  });
}
