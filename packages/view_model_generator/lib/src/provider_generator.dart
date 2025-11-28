import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:view_model_annotation/view_model_annotation.dart';

class ViewModelProviderGenerator extends GeneratorForAnnotation<GenProvider> {
  const ViewModelProviderGenerator();

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // 1. Ensure it is a class element
    if (element is! ClassElement) return '';

    // 2. Get class name (name is String? in newer analyzer versions, need to handle null)
    final className = element.name;
    if (className == null || className.isEmpty) {
      return '// Error: Class name is empty';
    }

    final providerName = _toLowerCamel(className) + 'Provider';

    // 3. Only take the main constructor (Unnamed Constructor)
    // According to source code, unnamedConstructor automatically looks for constructors named "new" or ""
    final ConstructorElement? ctor = element.unnamedConstructor;

    if (ctor == null) {
      return '// Skipped: No unnamed constructor (main constructor) found for $className';
    }

    // 4. Fix 'parameters' error
    // Based on source: ConstructorElement -> ExecutableElementImpl -> has formalParameters
    // Do not use .parameters anymore, use .formalParameters instead
    final params = ctor.formalParameters;

    // Filter required parameters and ignore superclass-forwarded parameters (super.xxx)
    final requiredParams = params
        .where((p) => p.isRequiredPositional || p.isRequiredNamed)
        .where((p) => p is! SuperFormalParameterElement)
        .toList();
    final count = requiredParams.length;

    final buffer = StringBuffer();

    // Generation logic
    if (count == 0) {
      buffer.writeln('final $providerName = ViewModelProvider<$className>(');
      buffer.writeln('  builder: () => $className(),');
      buffer.writeln(');');
    } else if (count > 0 && count <= 4) {
      final typeArguments = <String>[className];
      final builderArgs = <String>[];
      final constructorArgs = <String>[];

      for (var i = 0; i < count; i++) {
        final param = requiredParams[i];
        final argName = param.name!;

        // 5. Must set withNullability: true, otherwise generated code will lose nullable symbol '?'
        final typeStr = param.type.getDisplayString();

        typeArguments.add(typeStr);
        builderArgs.add('$typeStr $argName');

        // Handle named parameters (id: a) and positional parameters (a)
        if (param.isNamed) {
          constructorArgs.add('${param.name}: $argName');
        } else {
          constructorArgs.add(argName);
        }
      }

      final suffix = count == 1 ? '' : '$count';

      buffer.writeln(
          'final $providerName = ViewModelProvider.arg$suffix<${typeArguments.join(', ')}>(');
      buffer.writeln(
          '  builder: (${builderArgs.join(', ')}) => $className(${constructorArgs.join(', ')}),');
      buffer.writeln(');');
    } else {
      buffer.writeln('// Skipped: constructor with > 4 required parameters');
    }

    return buffer.toString();
  }

  String _toLowerCamel(String name) {
    if (name.isEmpty) return name;
    final first = name[0].toLowerCase();
    return '$first${name.substring(1)}';
  }
}
