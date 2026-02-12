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
    if (element is! ClassElement) return '';

    final className = element.name;
    if (className == null || className.isEmpty) {
      return '// Error: Class name is empty';
    }

    final specName = _specVarName(className);

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
      final anno = _readAnnotationArgs(element);
      if (keyExpr == null) {
        keyExpr = anno['key'];
        if (keyExpr != null) keyIsString = _isStringLiteral(keyExpr.trim());
      }
      if (tagExpr == null) {
        tagExpr = anno['tag'];
        if (tagExpr != null) tagIsString = _isStringLiteral(tagExpr.trim());
      }
      if (!aliveForever) {
        final af = anno['aliveForever'];
        if (af == 'true') aliveForever = true;
      }
    }

    final ConstructorElement? mainCtor = element.unnamedConstructor;
    final matchingFactory = _findSpecFactory(element);

    if (mainCtor == null && matchingFactory == null) {
      return '// Skipped: No unnamed constructor or spec factory for $className';
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
                ? _quoteString(k)
                : _normalizeStringLiteral(k))
            : (_unwrapExpr(k) ?? k);
        buffer.writeln('  key: $expr,');
      }
      if (tagExpr != null) {
        final t = tagExpr.trim();
        final expr = tagIsString
            ? (tagFromReaderString
                ? _quoteString(t)
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
      return '// Skipped: constructor with > 4 required parameters';
    }

    // Prepare builder signature
    final builderArgs = <String>[];
    final typeArgs = <String>[className];
    final callArgs = <String>[];

    for (final p in effectiveParams) {
      final typeStr = p.type.getDisplayString(withNullability: true);
      typeArgs.add(typeStr);
      builderArgs.add('$typeStr ${p.name}');
      callArgs.add(p.isNamed ? '${p.name}: ${p.name}' : p.name);
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
          ? (keyFromReaderString ? _quoteString(k) : _normalizeStringLiteral(k))
          : (_unwrapExpr(k) ??
              (_isStringLiteral(k) ? _normalizeStringLiteral(k) : k));
      buffer.writeln('  key: (${builderArgs.join(', ')}) => $expr,');
    }
    if (tagExpr != null) {
      final t = tagExpr.trim();
      final expr = tagIsString
          ? (tagFromReaderString ? _quoteString(t) : _normalizeStringLiteral(t))
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

  String _normalizeStringLiteral(String s) {
    if (s.startsWith("r'")) return "'${s.substring(2)}";
    if (s.startsWith('r"')) return '"${s.substring(2)}';
    return s;
  }

  String _quoteString(String s) {
    final escaped = s.replaceAll("'", "\\'");
    return "'${escaped}'";
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
  List _ownParams(ExecutableElement exec) {
    return exec.formalParameters
        .where((p) => p is! SuperFormalParameterElement)
        .toList();
  }

  /// Collect only required class-owned params (exclude super-forwarded).
  ///
  /// Used for main constructor to only include required parameters.
  List _requiredOwnParams(ExecutableElement exec) {
    return exec.formalParameters
        .where((p) =>
            (p as dynamic).isRequiredPositional ||
            (p as dynamic).isRequiredNamed)
        .where((p) => p is! SuperFormalParameterElement)
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
