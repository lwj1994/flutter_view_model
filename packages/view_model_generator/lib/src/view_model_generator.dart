import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:view_model_generator/src/provider_generator.dart';

/// A builder that generates ViewModel provider code.
///
/// It uses [ViewModelProviderGenerator] to process files and generates part files
/// with the extension `.vm.dart`.
Builder viewModelProviderBuilder(BuilderOptions options) {
  return PartBuilder(
    [ViewModelProviderGenerator()],
    '.vm.dart',
  );
}
