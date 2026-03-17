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

    // Read key/tag from annotation: prefer typed Expr, fallback to raw source.
    const exprChecker = TypeChecker.fromUrl(
        'package:view_model_annotation/src/annotation.dart#Expression');

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

    // Fallback: parse raw annotation source when not using Expr
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

    // Variant selection
    if (argCount == 0) {
      // No-args provider
      final buffer = StringBuffer();
      buffer.writeln('final $specName = ViewModelSpec<$className>(');

      if (matchingFactory != null) {
        buffer
            .writeln('  builder: () => $className.${matchingFactory.name}(),');
      } else {
        buffer.writeln('  builder: () => $className(),');
      }
      if (keyExpr != null) {
        final k = keyExpr.trim();
        final expr = keyIsString
            ? (keyFromReaderString
                ? _quoteString(
                    k,
                    allowInterpolation: keyAllowsInterpolation,
                  )
                : _normalizeStringLiteral(k))
            : (_unwrapExpr(k) ?? k);
        buffer.writeln('  key: $expr,');
      }
      if (tagExpr != null) {
        final t = tagExpr.trim();
        final expr = tagIsString
            ? (tagFromReaderString
                ? _quoteString(
                    t,
                    allowInterpolation: tagAllowsInterpolation,
                  )
                : _normalizeStringLiteral(t))
            : (_unwrapExpr(t) ?? t);
        buffer.writeln('  tag: $expr,');
      }

      if (aliveForever) {
        buffer.writeln('  aliveForever: true,');
      }
      buffer.writeln(');');
      return buffer.toString();
    }

    if (argCount > 4) {
      throw InvalidGenerationSourceError(
        '$className has $argCount parameters, but only up to 4 are supported.',
        element: element,
      );
    }

    // Prepare builder signature
    final builderArgs = <String>[];
    final typeArgs = <String>[className];
    final callArgs = <String>[];

    for (final p in effectiveParams) {
      final typeStr = p.type.getDisplayString();
      final paramName = p.name ?? '_arg${callArgs.length}';
      typeArgs.add(typeStr);
      builderArgs.add('$typeStr $paramName');
      callArgs.add(p.isNamed ? '$paramName: $paramName' : paramName);
    }

    // Build the provider line with correct suffix: arg for 1, argN for N>=2
    final suffix = argCount == 1 ? '' : argCount.toString();
    final buffer = StringBuffer();
    buffer.writeln(
        'final $specName = ViewModelSpec.arg$suffix<${typeArgs.join(', ')}>(');
    buffer.writeln('  builder: (${builderArgs.join(', ')}) => ');

    // Builder expression
    if (matchingFactory != null) {
      final name = matchingFactory.name;
      buffer.writeln('      $className.$name(${callArgs.join(', ')}),');
    } else {
      buffer.writeln('      $className(${callArgs.join(', ')}),');
    }

    // Optional key/tag: for arg providers, always closures to match builder.
    if (keyExpr != null) {
      final k = keyExpr.trim();
      final expr = keyIsString
          ? (keyFromReaderString
              ? _quoteString(
                  k,
                  allowInterpolation: keyAllowsInterpolation,
                )
              : _normalizeStringLiteral(k))
          : (_unwrapExpr(k) ??
              (_isStringLiteral(k) ? _normalizeStringLiteral(k) : k));
      buffer.writeln('  key: (${builderArgs.join(', ')}) => $expr,');
    }
    if (tagExpr != null) {
      final t = tagExpr.trim();
      final expr = tagIsString
          ? (tagFromReaderString
              ? _quoteString(
                  t,
                  allowInterpolation: tagAllowsInterpolation,
                )
              : _normalizeStringLiteral(t))
          : (_unwrapExpr(t) ??
              (_isStringLiteral(t) ? _normalizeStringLiteral(t) : t));
      buffer.writeln('  tag: (${builderArgs.join(', ')}) => $expr,');
    }
    if (aliveForever) {
      buffer.writeln('  aliveForever: (${builderArgs.join(', ')}) => true,');
    }

    buffer.writeln(');');
    return buffer.toString();
  }

  String _toLowerCamel(String name) {
    if (name.isEmpty) return name;
    final first = name[0].toLowerCase();
    return '$first${name.substring(1)}';
  }

  /// Read annotation argument source texts for key/tag.
  Map<String, String?> _readAnnotationArgs(ClassElement el) {
    final metadata = (el.metadata is Iterable)
        ? (el.metadata as Iterable)
        : ((el.metadata as dynamic).annotations as Iterable);
    for (final meta in metadata) {
      final src = (meta as dynamic).toSource() as String;
      if (src.startsWith('@GenSpec') || src.startsWith('@genSpec')) {
        final key = _extractArg(src, 'key');
        final tag = _extractArg(src, 'tag');

        final aliveForever = _extractArg(src, 'aliveForever');
        return {'key': key, 'tag': tag, 'aliveForever': aliveForever};
      }
    }
    return {'key': null, 'tag': null};
  }

  String? _extractArg(String src, String name) {
    final startMatch = RegExp(name + r"\s*:").firstMatch(src);
    if (startMatch == null) return null;
    var i = startMatch.end;
    // Skip whitespace
    while (i < src.length && (src[i] == ' ' || src[i] == '\n')) {
      i++;
    }
    final sb = StringBuffer();
    int depth = 0;
    while (i < src.length) {
      final ch = src[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        if (depth == 0) {
          // End at top-level ')'
          break;
        }
        depth--;
      } else if (ch == ',' && depth == 0) {
        break;
      }
      sb.write(ch);
      i++;
    }
    final expr = sb.toString().trim();
    return expr.isEmpty ? null : expr;
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
    if (s.startsWith("r'")) return "'${s.substring(2)}";
    if (s.startsWith('r"')) return '"${s.substring(2)}';
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
    // Skip spaces
    while (i < s.length && (s[i] == ' ' || s[i] == '\n' || s[i] == '\t')) {
      i++;
    }
    // Optional raw prefix
    if (i < s.length && s[i] == 'r') i++;
    while (i < s.length && (s[i] == ' ' || s[i] == '\n' || s[i] == '\t')) {
      i++;
    }
    if (i >= s.length) return null;
    final quote = s[i];
    if (quote != '\'' && quote != '"') return null;
    i++;
    final buf = StringBuffer();
    while (i < s.length) {
      final ch = s[i];
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
