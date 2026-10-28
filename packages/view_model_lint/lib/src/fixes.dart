part of 'rules.dart';

typedef ViewModelFixGenerator =
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    });

/// IDE quick fixes for each diagnostic. Plugin fixes cannot be applied in
/// bulk, so every fix is single-location and only edits what it can prove.
final viewModelFixes = <ViewModelRuleKind, List<ViewModelFixGenerator>>{
  ViewModelRuleKind.cachedInstance: [_ConvertToGetter.new],
  ViewModelRuleKind.aliveForeverKey: [_AddSpecKey.new],
  ViewModelRuleKind.selectorWithWatch: [_UseRead.new],
  ViewModelRuleKind.temporarySpec: [_MakeSpecStatic.new, _ExtractSpec.new],
};

LintCode viewModelCode(ViewModelRuleKind kind) => _codes[kind]!;

/// The diagnostic name as `dart analyze` reports it.
// Shared API across analyzer 8-10; lowerCaseName was added later.
// ignore: deprecated_member_use
String viewModelCodeName(ViewModelRuleKind kind) => _codes[kind]!.name;

const _readCounterparts = {
  'watch': 'read',
  'watchViewModel': 'readViewModel',
  'watchCached': 'readCached',
  'maybeWatchCached': 'maybeReadCached',
  'watchCachedViewModel': 'readCachedViewModel',
  'maybeWatchCachedViewModel': 'maybeReadCachedViewModel',
};

abstract class _ViewModelFix extends ResolvedCorrectionProducer {
  _ViewModelFix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  /// The node the diagnostic was reported at: the innermost node whose
  /// range matches the diagnostic exactly.
  AstNode? get reported {
    // Batch fixing passes the reported range as the selection, without a
    // diagnostic object.
    final offset =
        diagnosticOffset ??
        (selectionOffset >= 0 ? selectionOffset : node.offset);
    final length =
        diagnosticLength ??
        (selectionOffset >= 0 ? selectionLength : node.length);
    for (
      AstNode? current = node;
      current != null && current.offset == offset;
      current = current.parent
    ) {
      if (current.length == length) return current;
    }
    return null;
  }

  /// The reported expression with parentheses and `!` removed outward, and
  /// the parent that receives it.
  (Expression, AstNode?)? get reportedExpression {
    final expression = reported;
    if (expression is! Expression) return null;
    AstNode child = expression;
    while (child.parent is ParenthesizedExpression ||
        child.parent is PostfixExpression &&
            (child.parent as PostfixExpression).operator.type ==
                TokenType.BANG) {
      child = child.parent!;
    }
    return (child as Expression, child.parent);
  }
}

/// `late final X x = binding.read(spec);` -> `X get x => binding.read(spec);`
class _ConvertToGetter extends _ViewModelFix {
  static const _kind = FixKind(
    'view_model.fix.convertToGetter',
    DartFixKindPriority.standard,
    'Resolve the ViewModel in a getter on every access',
  );

  _ConvertToGetter({required super.context});

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final (initializer, variable) = reportedExpression ?? (null, null);
    if (initializer == null ||
        variable is! VariableDeclaration ||
        variable.initializer != initializer) {
      return;
    }
    final list = variable.parent;
    if (list is! VariableDeclarationList ||
        list.variables.length != 1 ||
        !list.isFinal ||
        list.isConst) {
      return;
    }
    final declaration = list.parent;
    final bool isStatic;
    if (declaration is FieldDeclaration) {
      if (declaration.externalKeyword != null ||
          declaration.abstractKeyword != null ||
          declaration.covariantKeyword != null) {
        return;
      }
      isStatic = declaration.isStatic;
    } else if (declaration is TopLevelVariableDeclaration) {
      if (declaration.externalKeyword != null) return;
      isStatic = false;
    } else {
      return;
    }
    final annotation = list.type;
    final type = variable.declaredFragment?.element.type;
    if (annotation == null && !_isVm(type)) return;
    final annotated = declaration as AnnotatedNode;
    final start = annotated.firstTokenAfterCommentAndMetadata.offset;
    final value = utils.getNodeText(initializer);
    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.startOffsetEndOffset(start, annotated.end), (
        builder,
      ) {
        if (isStatic) builder.write('static ');
        if (annotation != null) {
          builder.write(utils.getNodeText(annotation));
        } else {
          builder.writeType(type);
        }
        builder.write(' get ${variable.name.lexeme} => $value;');
      });
    });
  }
}

/// Adds a key derived from the spec's variable name to an `aliveForever`
/// spec, or replaces a literal null key.
class _AddSpecKey extends _ViewModelFix {
  static const _kind = FixKind(
    'view_model.fix.addSpecKey',
    DartFixKindPriority.standard,
    "Add the key {0}",
  );

  _AddSpecKey({required super.context});

  String _key = '';

  @override
  List<String> get fixArguments => [_key];

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final spec = reported;
    if (spec is! Expression) return;
    final arguments = _spec(spec);
    if (arguments == null) return;
    final aliveArgument = arguments.arguments
        .whereType<NamedExpression>()
        .where((argument) => argument.name.label.name == 'aliveForever')
        .firstOrNull;
    final arity = _arity(spec);
    if (aliveArgument == null || arity == null) return;
    final name = "'${_specKeyName(spec)}'";
    final parameters = [
      for (var i = 1; i <= arity; i++) arity == 1 ? 'arg' : 'arg$i',
    ];
    _key = arity == 0
        ? name
        : '(${parameters.join(', ')}) => (${[name, ...parameters].join(', ')})';
    final existing = _argument(arguments, 'key');
    // Keep one argument per line when the call is laid out that way.
    final content = unitResult.content;
    final lineStart = content.lastIndexOf('\n', aliveArgument.offset - 1) + 1;
    final indent = content.substring(lineStart, aliveArgument.offset);
    final separator = indent.trim().isEmpty ? ',$defaultEol$indent' : ', ';
    await builder.addDartFileEdit(file, (builder) {
      if (existing != null) {
        builder.addSimpleReplacement(range.node(existing), _key);
      } else {
        builder.addSimpleInsertion(
          aliveArgument.offset,
          'key: $_key$separator',
        );
      }
    });
  }

  /// Argument count of a parameterized spec, or 0 for a plain spec.
  static int? _arity(Expression spec) {
    final name = switch (spec) {
      InstanceCreationExpression() =>
        spec.constructorName.element?.enclosingElement.name,
      MethodInvocation() => spec.methodName.name,
      _ => null,
    };
    if (name == null) return null;
    if (name == 'ViewModelSpec' || name == 'ViewModelProvider') return 0;
    final suffix = name.startsWith('ViewModelSpecWithArg')
        ? name.substring('ViewModelSpecWithArg'.length)
        : name.startsWith('arg')
        ? name.substring('arg'.length)
        : null;
    if (suffix == null) return null;
    return suffix.isEmpty ? 1 : int.tryParse(suffix);
  }
}

/// `viewModel: binding.watch(spec)` -> `viewModel: binding.read(spec)`.
class _UseRead extends _ViewModelFix {
  static const _kind = FixKind(
    'view_model.fix.useRead',
    DartFixKindPriority.standard,
    "Resolve with '{0}' instead of '{1}'",
  );

  _UseRead({required super.context});

  List<String> _names = const [];

  @override
  List<String> get fixArguments => _names;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var expression = reported;
    while (expression is ParenthesizedExpression) {
      expression = expression.expression;
    }
    if (expression is PostfixExpression &&
        expression.operator.type == TokenType.BANG) {
      expression = expression.operand;
    }
    if (expression is! MethodInvocation || !_calls(expression, _watchMethods)) {
      return;
    }
    final watch = expression.methodName;
    final read = _readCounterparts[watch.name];
    if (read == null) return;
    _names = [read, watch.name];
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(watch), read);
    });
  }
}

/// A spec in an instance field initializer becomes a static field.
class _MakeSpecStatic extends _ViewModelFix {
  static const _kind = FixKind(
    'view_model.fix.makeSpecStatic',
    DartFixKindPriority.standard,
    'Make the spec a static field',
  );

  _MakeSpecStatic({required super.context});

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final (spec, variable) = reportedExpression ?? (null, null);
    if (spec == null ||
        variable is! VariableDeclaration ||
        variable.initializer != spec) {
      return;
    }
    final declaration = variable.parent?.parent;
    if (declaration is! FieldDeclaration ||
        declaration.isStatic ||
        declaration.externalKeyword != null ||
        declaration.abstractKeyword != null ||
        declaration.covariantKeyword != null ||
        _Captures.of(spec, allowStaticMembers: true)) {
      return;
    }
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        declaration.firstTokenAfterCommentAndMetadata.offset,
        'static ',
      );
    });
  }
}

/// Moves a spec that captures nothing from its scope to a private
/// top-level final and references that variable instead.
class _ExtractSpec extends _ViewModelFix {
  static const _kind = FixKind(
    'view_model.fix.extractSpec',
    DartFixKindPriority.standard,
    "Move the spec to the top-level variable '{0}'",
  );

  _ExtractSpec({required super.context});

  String _name = '';

  @override
  List<String> get fixArguments => [_name];

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final spec = reported;
    if (spec is! Expression || _Captures.of(spec)) return;
    final type = spec.staticType;
    if (type == null || _mentionsTypeParameter(type)) return;
    // An instance field is better served by the static-field fix.
    final (_, holder) = reportedExpression ?? (null, null);
    if (holder is VariableDeclaration &&
        holder.parent?.parent is FieldDeclaration) {
      return;
    }
    final member = spec.thisOrAncestorMatching(
      (node) => node.parent is CompilationUnit,
    );
    if (member == null) return;
    _name = _uniqueName(_baseName(spec));
    final value = utils.getNodeText(spec);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(spec), _name);
      builder.addSimpleInsertion(
        member.end,
        '$defaultEol${defaultEol}final $_name = $value;',
      );
    });
  }

  String _baseName(Expression spec) {
    final type = spec.staticType;
    if (type is! InterfaceType) return 'spec';
    final element = type.element;
    if (_specClasses.contains(element.name)) {
      if (type.typeArguments.firstOrNull case final InterfaceType vm) {
        return '${_lowerFirst(vm.element.name ?? 'view')}Spec';
      }
    }
    return _lowerFirst(element.name ?? 'spec');
  }

  /// A private name no unit of the library mentions, so the new top-level
  /// variable cannot collide with or shadow an existing declaration.
  String _uniqueName(String base) {
    final sources = [for (final unit in libraryResult.units) unit.content];
    bool taken(String name) {
      final word = RegExp('(?<![\\w\$])${RegExp.escape(name)}(?![\\w\$])');
      return sources.any(word.hasMatch);
    }

    var name = '_$base';
    for (var i = 2; taken(name); i++) {
      name = '_$base$i';
    }
    return name;
  }
}

/// Whether [expression] reads `this`, an enclosing member without a
/// qualifier, or a local, parameter, or type parameter declared outside it.
class _Captures extends RecursiveAstVisitor<void> {
  final Set<Element> inner;
  final bool allowStaticMembers;
  bool found = false;

  _Captures(this.inner, {required this.allowStaticMembers});

  static bool of(Expression expression, {bool allowStaticMembers = false}) {
    final inner = <Element>{};
    expression.accept(_Declared(inner));
    final visitor = _Captures(inner, allowStaticMembers: allowStaticMembers);
    expression.accept(visitor);
    return visitor.found;
  }

  @override
  void visitThisExpression(ThisExpression node) => found = true;

  @override
  void visitSuperExpression(SuperExpression node) => found = true;

  @override
  void visitNamedType(NamedType node) {
    final element = node.element;
    if (element is TypeParameterElement && !inner.contains(element)) {
      found = true;
    }
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final parent = node.parent;
    // Labels and members reached through an explicit target are not scope
    // references.
    if (parent is Label ||
        parent is PropertyAccess && parent.propertyName == node ||
        parent is PrefixedIdentifier && parent.identifier == node ||
        parent is MethodInvocation &&
            parent.methodName == node &&
            parent.target != null) {
      return;
    }
    final element = node.element?.baseElement;
    if (element == null || inner.contains(element)) return;
    if (element is LocalVariableElement ||
        element is FormalParameterElement ||
        element is TypeParameterElement ||
        element is LocalFunctionElement) {
      found = true;
      return;
    }
    final enclosing = element.enclosingElement;
    if (enclosing is InterfaceElement && element is! ConstructorElement) {
      final isStatic = switch (element) {
        ExecutableElement(:final isStatic) => isStatic,
        FieldElement(:final isStatic) => isStatic,
        _ => false,
      };
      if (!isStatic || !allowStaticMembers) found = true;
    }
  }
}

bool _mentionsTypeParameter(DartType type) => switch (type) {
  TypeParameterType() => true,
  InterfaceType(:final typeArguments) => typeArguments.any(
    _mentionsTypeParameter,
  ),
  FunctionType(:final returnType, :final formalParameters) =>
    _mentionsTypeParameter(returnType) ||
        formalParameters.any((p) => _mentionsTypeParameter(p.type)),
  RecordType(:final positionalFields, :final namedFields) =>
    positionalFields.any((f) => _mentionsTypeParameter(f.type)) ||
        namedFields.any((f) => _mentionsTypeParameter(f.type)),
  _ => false,
};

String _lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

/// The variable a spec initializes, without its `Spec` suffix, or the
/// ViewModel type name.
String _specKeyName(Expression spec) {
  AstNode child = spec;
  while (child.parent is ParenthesizedExpression) {
    child = child.parent!;
  }
  final parent = child.parent;
  if (parent is VariableDeclaration) {
    final name = parent.name.lexeme;
    final trimmed = name.endsWith('Spec')
        ? name.substring(0, name.length - 'Spec'.length)
        : name;
    final key = trimmed.startsWith('_') ? trimmed.substring(1) : trimmed;
    if (key.isNotEmpty) return key;
  }
  final type = spec.staticType;
  if (type is InterfaceType) {
    if (type.typeArguments.firstOrNull case final InterfaceType vm) {
      return _lowerFirst(vm.element.name ?? 'viewModel');
    }
  }
  return 'viewModel';
}
