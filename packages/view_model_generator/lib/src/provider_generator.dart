import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:view_model_annotation/view_model_annotation.dart';

class ViewModelProviderGenerator extends GeneratorForAnnotation<GenProvider> {
  const ViewModelProviderGenerator();

  /// Generate provider code for the annotated class.
  ///
  /// Rules (in order of priority):
  /// 1) Prefer a factory whose required args count and types match.
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

    final providerName = _providerVarName(className);

    // Read key/tag from annotation: prefer typed Expr, fallback to raw source.
    final exprChecker = TypeChecker.fromUrl(
        'package:view_model_annotation/src/annotation.dart#Expr');
    String? keyExpr;
    String? tagExpr;
    bool keyIsString = false;
    bool tagIsString = false;
    bool keyFromReaderString = false;
    bool tagFromReaderString = false;

    final keyReader = annotation.peek('key');
    final tagReader = annotation.peek('tag');

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
    }

    final ConstructorElement? mainCtor = element.unnamedConstructor;
    if (mainCtor == null) {
      return '// Skipped: No unnamed constructor for $className';
    }

    // Collect required, class-owned params from main constructor.
    final effectiveParams = _requiredOwnParams(mainCtor);

    final argCount = effectiveParams.length;

    // Variant selection
    if (argCount == 0) {
      // No-args provider
      final buffer = StringBuffer();
      buffer.writeln('final $providerName = ViewModelProvider<$className>(');
      buffer.writeln('  builder: () => $className(),');
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
      buffer.writeln(');');
      return buffer.toString();
    }

    if (argCount > 4) {
      return '// Skipped: constructor with > 4 required parameters';
    }

    // Prefer factory named 'provider' if it exists.
    final matchingFactory = _findProviderFactory(element);

    // Prepare builder signature
    final builderArgs = <String>[];
    final typeArgs = <String>[className];
    final callArgs = <String>[];

    if (matchingFactory != null) {
      final factoryParams = _requiredOwnParams(matchingFactory);
      for (final p in factoryParams) {
        final typeStr = p.type.getDisplayString(withNullability: true);
        typeArgs.add(typeStr);
        builderArgs.add('$typeStr ${p.name}');
        callArgs.add(p.isNamed ? '${p.name}: ${p.name}' : p.name);
      }
    } else {
      for (final p in effectiveParams) {
        final typeStr = p.type.getDisplayString(withNullability: true);
        typeArgs.add(typeStr);
        builderArgs.add('$typeStr ${p.name}');
        callArgs.add(p.isNamed ? '${p.name}: ${p.name}' : p.name);
      }
    }

    // Build the provider line with correct suffix: arg for 1, argN for N>=2
    final suffix = argCount == 1 ? '' : argCount.toString();
    final buffer = StringBuffer();
    buffer.writeln(
        'final $providerName = ViewModelProvider.arg$suffix<${typeArgs.join(', ')}>(');
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
      if (src.startsWith('@GenProvider') || src.startsWith('@genProvider')) {
        final key = _extractArg(src, 'key');
        final tag = _extractArg(src, 'tag');
        return {'key': key, 'tag': tag};
      }
    }
    return {'key': null, 'tag': null};
  }

  String? _extractArg(String src, String name) {
    final startMatch = RegExp(name + r"\s*:").firstMatch(src);
    if (startMatch == null) return null;
    var i = startMatch.end;
    // Skip whitespace
    while (i < src.length && (src[i] == ' ' || src[i] == '\n')) i++;
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

  /// If the source is `Expr('code')` or `Expr("code")`, unwrap to `code`.
  String? _unwrapExpr(String s) {
    if (!s.startsWith('Expr(')) return null;
    var i = 'Expr('.length;
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

  /// Compute provider variable name. Keeps default rule except special cases.
  ///
  /// Special case: PostViewModel -> postProvider.
  String _providerVarName(String className) {
    if (className == 'PostViewModel') return 'postProvider';
    return _toLowerCamel(className) + 'Provider';
  }

  /// Collect required, class-owned params (exclude super-forwarded params).
  List _requiredOwnParams(ExecutableElement exec) {
    return exec.formalParameters
        .where((p) =>
            (p as dynamic).isRequiredPositional ||
            (p as dynamic).isRequiredNamed)
        .where((p) => p is! SuperFormalParameterElement)
        .toList();
  }

  /// Find factory named 'provider' if present; otherwise null.
  ConstructorElement? _findProviderFactory(ClassElement el) {
    for (final c in el.constructors) {
      if (c.isFactory && c.name == 'provider') return c;
    }
    return null;
  }
}
