import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:view_model_annotation/view_model_annotation.dart';

class ViewModelSpecGenerator extends GeneratorForAnnotation<GenSpec> {
  const ViewModelSpecGenerator();

  /// Generate spec code for the annotated class.
  ///
  /// Rules (in order of priority):
  /// 1) Prefer a factory named 'spec'.
  /// 2) Otherwise use the main (unnamed) constructor.
  /// 3) No special handling for `StateViewModel`; use constructors as-is.
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@GenSpec can only be applied to classes.',
        element: element,
      );
    }

    final className = element.name;
    if (className == null || className.isEmpty) {
      throw InvalidGenerationSourceError(
        'Class name is empty.',
        element: element,
      );
    }

    final specName = _specVarName(className);
    final annotationArgs = _readAnnotationArgs(element);
    final classTypeParams = element.typeParameters.toList();
    final classTypeParamDecls =
        _typeParameterDeclarationClause(classTypeParams);
    final classTypeParamRefs = _typeParameterReferenceClause(classTypeParams);
    final instantiatedClassName = classTypeParamRefs.isEmpty
        ? className
        : '$className$classTypeParamRefs';

    // Read key/tag from annotation: prefer typed Expr, fallback to raw source.
    const exprChecker = TypeChecker.fromUrl(
      'package:view_model_annotation/src/annotation.dart#Expression',
    );

    String? keyExpr;
    String? tagExpr;
    bool keyIsString = false;
    bool tagIsString = false;
    bool keyFromReaderString = false;
    bool tagFromReaderString = false;
    final keyReader = annotation.peek('key');
    final tagReader = annotation.peek('tag');
    final keyAllowsInterpolation = _shouldAllowStringInterpolation(
      keyReader,
      annotationArgs['key']?.trim() ?? '',
    );
    final tagAllowsInterpolation = _shouldAllowStringInterpolation(
      tagReader,
      annotationArgs['tag']?.trim() ?? '',
    );

    final aliveForeverReader = annotation.peek('aliveForever');
    bool aliveForever = aliveForeverReader?.boolValue ?? false;

    if (keyReader != null && keyReader.instanceOf(exprChecker)) {
      keyExpr = keyReader.peek('code')?.stringValue;
      keyIsString = false;
    } else if (keyReader != null && keyReader.isString) {
      keyExpr = keyReader.stringValue;
      keyIsString = true;
      keyFromReaderString = true;
    }
    if (tagReader != null && tagReader.instanceOf(exprChecker)) {
      tagExpr = tagReader.peek('code')?.stringValue;
      tagIsString = false;
    } else if (tagReader != null && tagReader.isString) {
      tagExpr = tagReader.stringValue;
      tagIsString = true;
      tagFromReaderString = true;
    }

    // Fallback: parse raw annotation source when not using Expr.
    if (keyExpr == null || tagExpr == null) {
      if (keyExpr == null) {
        keyExpr = annotationArgs['key'];
        if (keyExpr != null) keyIsString = _isStringLiteral(keyExpr.trim());
      }
      if (tagExpr == null) {
        tagExpr = annotationArgs['tag'];
        if (tagExpr != null) tagIsString = _isStringLiteral(tagExpr.trim());
      }
      if (!aliveForever) {
        final af = annotationArgs['aliveForever'];
        if (af == 'true') aliveForever = true;
      }
    }

    final ConstructorElement? mainCtor = element.unnamedConstructor;
    final matchingFactory = _findSpecFactory(element);

    if (mainCtor == null && matchingFactory == null) {
      throw InvalidGenerationSourceError(
        '$className must have an unnamed constructor or a factory named '
        '`spec`.',
        element: element,
      );
    }

    // Collect class-owned params.
    // Priority: factory 'spec' (all params), then main constructor
    // (required only).
    // Factory spec collects ALL params (including optional) to give full
    // control. Main constructor only collects REQUIRED params for simplicity.
    final effectiveParams = matchingFactory != null
        ? _ownParams(matchingFactory)
        : _requiredOwnParams(mainCtor!);

    final argCount = effectiveParams.length;

    if (argCount > 4) {
      throw InvalidGenerationSourceError(
        '$className has $argCount parameters, but only up to 4 are supported.',
        element: element,
      );
    }

    if (argCount == 0) {
      final buffer = StringBuffer();
      final isGenericClass = classTypeParams.isNotEmpty;
      final indent = isGenericClass ? '  ' : '';

      if (isGenericClass) {
        buffer.writeln(
          'ViewModelSpec<$instantiatedClassName> '
          '$specName$classTypeParamDecls() {',
        );
        buffer.writeln('  return ViewModelSpec<$instantiatedClassName>(');
      } else {
        buffer.writeln(
            'final $specName = ViewModelSpec<$instantiatedClassName>(');
      }

      if (matchingFactory != null) {
        buffer.writeln(
          '${indent}  builder: () => '
          '$instantiatedClassName.${matchingFactory.name}(),',
        );
      } else {
        buffer.writeln(
          '${indent}  builder: () => $instantiatedClassName(),',
        );
      }

      if (keyExpr != null) {
        final expr = _formatGeneratedExpression(
          rawExpression: keyExpr,
          isString: keyIsString,
          fromReaderString: keyFromReaderString,
          allowInterpolation: keyAllowsInterpolation,
        );
        buffer.writeln('${indent}  key: $expr,');
      }

      if (tagExpr != null) {
        final expr = _formatGeneratedExpression(
          rawExpression: tagExpr,
          isString: tagIsString,
          fromReaderString: tagFromReaderString,
          allowInterpolation: tagAllowsInterpolation,
        );
        buffer.writeln('${indent}  tag: $expr,');
      }

      if (aliveForever) {
        buffer.writeln('${indent}  aliveForever: true,');
      }

      if (isGenericClass) {
        buffer.writeln('  );');
        buffer.writeln('}');
      } else {
        buffer.writeln(');');
      }

      return buffer.toString();
    }

    final builderArgs = <String>[];
    final parameterTypes = <String>[];
    final typeArgs = <String>[instantiatedClassName];
    final callArgs = <String>[];

    for (final p in effectiveParams) {
      final typeStr = p.type.getDisplayString();
      final paramName = p.name ?? '_arg${callArgs.length}';
      parameterTypes.add(typeStr);
      typeArgs.add(typeStr);
      builderArgs.add('$typeStr $paramName');
      callArgs.add(p.isNamed ? '$paramName: $paramName' : paramName);
    }

    final suffix = argCount == 1 ? '' : argCount.toString();
    final buffer = StringBuffer();
    final isGenericClass = classTypeParams.isNotEmpty;
    final indent = isGenericClass ? '  ' : '';

    if (isGenericClass) {
      buffer.writeln(
        '${_argSpecReturnType(
          instantiatedClassName: instantiatedClassName,
          parameterTypes: parameterTypes,
        )} $specName$classTypeParamDecls() {',
      );
      buffer.writeln(
        '  return ViewModelSpec.arg$suffix<${typeArgs.join(', ')}>(',
      );
    } else {
      buffer.writeln(
        'final $specName = ViewModelSpec.arg$suffix<${typeArgs.join(', ')}>(',
      );
    }

    buffer.writeln('${indent}  builder: (${builderArgs.join(', ')}) => ');

    if (matchingFactory != null) {
      buffer.writeln(
        '${indent}      $instantiatedClassName.${matchingFactory.name}'
        '(${callArgs.join(', ')}),',
      );
    } else {
      buffer.writeln(
        '${indent}      $instantiatedClassName(${callArgs.join(', ')}),',
      );
    }

    if (keyExpr != null) {
      final expr = _formatGeneratedExpression(
        rawExpression: keyExpr,
        isString: keyIsString,
        fromReaderString: keyFromReaderString,
        allowInterpolation: keyAllowsInterpolation,
      );
      buffer.writeln(
        '${indent}  key: (${builderArgs.join(', ')}) => $expr,',
      );
    }

    if (tagExpr != null) {
      final expr = _formatGeneratedExpression(
        rawExpression: tagExpr,
        isString: tagIsString,
        fromReaderString: tagFromReaderString,
        allowInterpolation: tagAllowsInterpolation,
      );
      buffer.writeln(
        '${indent}  tag: (${builderArgs.join(', ')}) => $expr,',
      );
    }

    if (aliveForever) {
      buffer.writeln(
        '${indent}  aliveForever: (${builderArgs.join(', ')}) => true,',
      );
    }

    if (isGenericClass) {
      buffer.writeln('  );');
      buffer.writeln('}');
    } else {
      buffer.writeln(');');
    }

    return buffer.toString();
  }

  String _formatGeneratedExpression({
    required String rawExpression,
    required bool isString,
    required bool fromReaderString,
    required bool allowInterpolation,
  }) {
    final expression = rawExpression.trim();
    if (!isString) {
      return _unwrapExpr(expression) ??
          (_isStringLiteral(expression)
              ? _normalizeStringLiteral(expression)
              : expression);
    }

    if (fromReaderString) {
      return _quoteString(
        expression,
        allowInterpolation: allowInterpolation,
      );
    }

    return _normalizeStringLiteral(expression);
  }

  String _toLowerCamel(String name) {
    if (name.isEmpty) return name;
    final first = name[0].toLowerCase();
    return '$first${name.substring(1)}';
  }

  String _typeParameterDeclarationClause(
    List<TypeParameterElement> parameters,
  ) {
    if (parameters.isEmpty) return '';
    final formatted =
        parameters.map(_formatTypeParameterDeclaration).join(', ');
    return '<$formatted>';
  }

  String _typeParameterReferenceClause(
    List<TypeParameterElement> parameters,
  ) {
    if (parameters.isEmpty) return '';
    final formatted = parameters
        .map((parameter) => parameter.name ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');
    return '<$formatted>';
  }

  String _formatTypeParameterDeclaration(TypeParameterElement parameter) {
    final name = parameter.name ?? '';
    final bound = parameter.bound?.getDisplayString();
    if (bound == null || bound == 'dynamic') {
      return name;
    }
    return '$name extends $bound';
  }

  String _argSpecReturnType({
    required String instantiatedClassName,
    required List<String> parameterTypes,
  }) {
    final suffix =
        parameterTypes.length == 1 ? '' : parameterTypes.length.toString();
    return 'ViewModelSpecWithArg$suffix<$instantiatedClassName, '
        '${parameterTypes.join(', ')}>';
  }

  /// Read annotation argument source texts for key/tag.
  Map<String, String?> _readAnnotationArgs(ClassElement el) {
    final metadata = (el.metadata is Iterable)
        ? (el.metadata as Iterable)
        : ((el.metadata as dynamic).annotations as Iterable);
    for (final meta in metadata) {
      final src = (meta as dynamic).toSource() as String;
      if (_isGenSpecAnnotationSource(src)) {
        final key = _extractArg(src, 'key');
        final tag = _extractArg(src, 'tag');
        final aliveForever = _extractArg(src, 'aliveForever');
        return {'key': key, 'tag': tag, 'aliveForever': aliveForever};
      }
    }
    return {'key': null, 'tag': null, 'aliveForever': null};
  }

  String? _extractArg(String src, String name) {
    final startMatch = RegExp(name + r"\s*:").firstMatch(src);
    if (startMatch == null) return null;
    var i = startMatch.end;

    while (i < src.length && _isWhitespace(src[i])) {
      i++;
    }

    final sb = StringBuffer();
    final delimiters = <String>[];
    String? stringQuote;
    bool isRawString = false;

    while (i < src.length) {
      final ch = src[i];

      if (stringQuote != null) {
        sb.write(ch);
        if (ch == stringQuote &&
            (isRawString || !_isEscapedStringCharacter(src, i))) {
          stringQuote = null;
          isRawString = false;
        }
        i++;
        continue;
      }

      if (ch == '\'' || ch == '"') {
        stringQuote = ch;
        isRawString = _isRawStringStart(src, i);
        sb.write(ch);
        i++;
        continue;
      }

      if (_isOpeningDelimiter(ch)) {
        delimiters.add(ch);
      } else if (_isClosingDelimiter(ch)) {
        if (delimiters.isEmpty) {
          if (ch == ')') {
            break;
          }
        } else if (_matchesDelimiter(delimiters.last, ch)) {
          delimiters.removeLast();
        }
      } else if (ch == ',' && delimiters.isEmpty) {
        break;
      }

      sb.write(ch);
      i++;
    }

    final expr = sb.toString().trim();
    return expr.isEmpty ? null : expr;
  }

  bool _isGenSpecAnnotationSource(String source) {
    return RegExp(r'^@(?:\w+\.)?(?:GenSpec|genSpec)\b').hasMatch(source.trim());
  }

  bool _isWhitespace(String ch) {
    return ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t';
  }

  // NOTE: `<`/`>` are treated as paired delimiters to support generic type
  // arguments in annotation values (e.g. `const <String>['a']`). This is safe
  // because comparison operators should not appear in const annotation args.
  bool _isOpeningDelimiter(String ch) {
    return ch == '(' || ch == '[' || ch == '{' || ch == '<';
  }

  bool _isClosingDelimiter(String ch) {
    return ch == ')' || ch == ']' || ch == '}' || ch == '>';
  }

  bool _matchesDelimiter(String opening, String closing) {
    return (opening == '(' && closing == ')') ||
        (opening == '[' && closing == ']') ||
        (opening == '{' && closing == '}') ||
        (opening == '<' && closing == '>');
  }

  bool _isEscapedStringCharacter(String source, int index) {
    var backslashCount = 0;
    for (var i = index - 1; i >= 0 && source[i] == r'\'; i--) {
      backslashCount++;
    }
    return backslashCount.isOdd;
  }

  bool _isRawStringStart(String source, int quoteIndex) {
    if (quoteIndex == 0 || source[quoteIndex - 1] != 'r') {
      return false;
    }
    if (quoteIndex >= 2 && _isIdentifierPart(source[quoteIndex - 2])) {
      return false;
    }
    return true;
  }

  bool _isIdentifierPart(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 95;
  }

  bool _isStringLiteral(String s) {
    return s.startsWith("'") ||
        s.startsWith('"') ||
        s.startsWith("r'") ||
        s.startsWith('r"');
  }

  bool _isRawStringLiteral(String s) {
    return s.startsWith("r'") || s.startsWith('r"');
  }

  bool _shouldAllowStringInterpolation(ConstantReader? reader, String source) {
    if (source.isEmpty) return false;
    if (_isRawStringLiteral(source)) return true;
    if (_isStringLiteral(source)) return false;

    final variable = reader?.objectValue.variable;
    if (variable == null) return false;
    return _isRawStringVariable(variable, <int>{});
  }

  bool _isRawStringVariable(VariableElement variable, Set<int> visited) {
    if (!visited.add(variable.id)) return false;

    final initializer = variable.constantInitializer?.toSource();
    if (initializer == null) return false;

    final source = initializer.trim();
    if (_isRawStringLiteral(source)) return true;
    if (_isStringLiteral(source)) return false;

    final library = variable.library;
    if (library == null) return false;

    final referenced = _resolveSimpleVariableReference(library, source);
    if (referenced == null) return false;
    return _isRawStringVariable(referenced, visited);
  }

  VariableElement? _resolveSimpleVariableReference(
    LibraryElement library,
    String source,
  ) {
    final identifier = source.trim();
    if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(identifier)) {
      return null;
    }

    for (final element in library.topLevelVariables) {
      if (element.name == identifier) {
        return element;
      }
    }
    return null;
  }

  String _normalizeStringLiteral(String s) {
    if (s.startsWith("r'") || s.startsWith('r"')) {
      final quote = s[1];
      final content = s.substring(2, s.length - 1);
      // Re-escape backslashes and dollar signs that gain special meaning
      // when converting from raw string to normal string.
      final escaped = content
          .replaceAll(r'\', r'\\')
          .replaceAll(r'$', r'\$')
          .replaceAll(quote, '\\$quote');
      return '$quote$escaped$quote';
    }
    return s;
  }

  String _quoteString(String s, {bool allowInterpolation = false}) {
    final buffer = StringBuffer("'");
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      switch (ch) {
        case r'\':
          buffer.write(r'\\');
          break;
        case "'":
          buffer.write(r"\'");
          break;
        case '\n':
          buffer.write(r'\n');
          break;
        case '\r':
          buffer.write(r'\r');
          break;
        case '\t':
          buffer.write(r'\t');
          break;
        case '\b':
          buffer.write(r'\b');
          break;
        case '\f':
          buffer.write(r'\f');
          break;
        case r'$':
          if (_shouldInterpolateDollar(
            s,
            i,
            allowInterpolation: allowInterpolation,
          )) {
            buffer.write(r'$');
          } else {
            buffer.write(r'\$');
          }
          break;
        default:
          buffer.write(ch);
      }
    }
    buffer.write("'");
    return buffer.toString();
  }

  bool _shouldInterpolateDollar(
    String value,
    int index, {
    required bool allowInterpolation,
  }) {
    if (!allowInterpolation || index + 1 >= value.length) {
      return false;
    }
    final next = value[index + 1];
    if (next != '{' && !_isIdentifierStart(next)) {
      return false;
    }
    var backslashCount = 0;
    for (var i = index - 1; i >= 0 && value[i] == r'\'; i--) {
      backslashCount++;
    }
    return backslashCount.isEven;
  }

  bool _isIdentifierStart(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 95;
  }

  /// If the source is `Expression('code')`, unwrap to `code`.
  String? _unwrapExpr(String s) {
    if (!s.startsWith('Expression(')) return null;
    var i = 'Expression('.length;
    while (i < s.length && _isWhitespace(s[i])) {
      i++;
    }
    if (i < s.length && s[i] == 'r') i++;
    while (i < s.length && _isWhitespace(s[i])) {
      i++;
    }
    if (i >= s.length) return null;
    final quote = s[i];
    if (quote != '\'' && quote != '"') return null;
    i++;
    final buf = StringBuffer();
    while (i < s.length) {
      final ch = s[i];
      if (ch == r'\' && i + 1 < s.length) {
        buf.write(ch);
        buf.write(s[++i]);
        i++;
        continue;
      }
      if (ch == quote) break;
      buf.write(ch);
      i++;
    }
    return buf.toString();
  }

  /// Compute spec variable name.
  ///
  /// Removes 'ViewModel' suffix if present, then camelCases and appends
  /// 'Spec'.
  /// Example: FollowPostViewModel -> followPostSpec
  String _specVarName(String className) {
    var name = className;
    if (name.endsWith('ViewModel')) {
      name = name.substring(0, name.length - 9);
    }
    return _toLowerCamel(name) + 'Spec';
  }

  /// Collect all class-owned params (exclude super-forwarded params).
  ///
  /// Used for factory spec to include both required and optional
  /// parameters.
  List<FormalParameterElement> _ownParams(ExecutableElement exec) {
    return exec.formalParameters
        .where((p) => p is! SuperFormalParameterElement)
        .cast<FormalParameterElement>()
        .toList();
  }

  /// Collect only required class-owned params (exclude super-forwarded).
  ///
  /// Used for main constructor to only include required parameters.
  List<FormalParameterElement> _requiredOwnParams(ExecutableElement exec) {
    return exec.formalParameters
        .where((p) => p.isRequiredPositional || p.isRequiredNamed)
        .where((p) => p is! SuperFormalParameterElement)
        .cast<FormalParameterElement>()
        .toList();
  }

  /// Find factory named 'spec' if present; otherwise null.
  ConstructorElement? _findSpecFactory(ClassElement el) {
    for (final c in el.constructors) {
      if (c.isFactory && c.name == 'spec') return c;
    }
    return null;
  }
}
