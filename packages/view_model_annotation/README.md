# view_model_annotation

Annotations for the `view_model` code generator.

## Installation

Add to your project:

```yaml
dependencies:
  view_model_annotation: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.0
  view_model_generator: ^1.0.0
```

## Usage

1. Import the annotation and mark your class.
2. Add a `part` for the generated file.
3. Run the build runner.

```dart
import 'package:view_model/view_model.dart';
import 'package:view_model_annotation/view_model_annotation.dart';

part 'my_view_model.vm.dart';

@GenSpec()
class MyViewModel extends ViewModel {
  // Your logic here
}
```

Then run:

```bash
dart run build_runner build
```

This will generate `my_view_model.vm.dart` containing a
`mySpec` variable.
