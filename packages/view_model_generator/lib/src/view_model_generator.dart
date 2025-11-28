import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:view_model_generator/src/provider_generator.dart';

Builder viewModelProviderBuilder(BuilderOptions options) {
  return PartBuilder(
    [ViewModelProviderGenerator()],
    '.vm.dart',
  );
}
