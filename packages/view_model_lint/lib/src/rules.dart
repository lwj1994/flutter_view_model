import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

enum ViewModelRuleKind {
  dependencyCycle,
  cachedInstance,
  aliveForeverKey,
  unmanagedConstruction,
}

const _codes = <ViewModelRuleKind, LintCode>{
  ViewModelRuleKind.dependencyCycle: LintCode(
    'view_model_dependency_cycle',
    'Potential ViewModel type dependency cycle: {0}.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Review the dependency graph. Keys and bindings can '
        'distinguish instances; runtime cycle validation still applies.',
  ),
  ViewModelRuleKind.cachedInstance: LintCode(
    'view_model_cached_instance',
    'A stored resolved ViewModel can remain stale after recycle.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Use a getter that resolves watch/read(spec) through '
        'the owner binding on every access.',
  ),
  ViewModelRuleKind.aliveForeverKey: LintCode(
    'view_model_alive_forever_key',
    'aliveForever is true without an explicit non-null key.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage: 'Supply an explicit key before resolving this spec.',
  ),
  ViewModelRuleKind.unmanagedConstruction: LintCode(
    'view_model_unmanaged_construction',
    'ViewModel constructed outside a spec builder or managed factory.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Construct it in a spec builder and resolve the spec '
        'through an owner binding.',
  ),
};

class ViewModelRule extends AnalysisRule {
  final ViewModelRuleKind kind;

  ViewModelRule(this.kind)
    : super(
        // Shared API across analyzer 8-10; lowerCaseName was added later.
        // ignore: deprecated_member_use
        name: _codes[kind]!.name,
        description: _codes[kind]!.problemMessage,
      );

  @override
  LintCode get diagnosticCode => _codes[kind]!;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

bool _inPackage(Element? element, [String package = 'view_model']) =>
    element?.library?.uri.scheme == 'package' &&
    element!.library!.uri.path.startsWith('$package/');

bool _isType(InterfaceElement element, String name) =>
    element.name == name && _inPackage(element);

bool _hasType(DartType? type, String name) =>
    type is InterfaceType &&
    (_isType(type.element, name) ||
        type.allSupertypes.any((type) => _isType(type.element, name)));

bool _isVm(DartType? type) => _hasType(type, 'ViewModel');

Expression _unwrap(Expression expression) =>
    expression is ParenthesizedExpression
    ? _unwrap(expression.expression)
    : expression;

Expression? _literalResult(Expression? expression) {
  if (expression == null) return null;
  expression = _unwrap(expression);
  if (expression is FunctionExpression) {
    final body = expression.body;
    if (body is ExpressionFunctionBody) return _literalResult(body.expression);
    if (body is BlockFunctionBody && body.block.statements.length == 1) {
      final statement = body.block.statements.single;
      if (statement is ReturnStatement) {
        return _literalResult(statement.expression);
      }
    }
  }
  return expression;
}

ArgumentList? _spec(Expression expression) {
  if (expression is InstanceCreationExpression) {
    final element = expression.constructorName.element?.enclosingElement;
    if (element == null || !_inPackage(element)) return null;
    if (element.name == 'ViewModelSpec') {
      return expression.argumentList;
    }
    if (const {
      'ViewModelSpecWithArg',
      'ViewModelSpecWithArg2',
      'ViewModelSpecWithArg3',
      'ViewModelSpecWithArg4',
    }.contains(element.name)) {
      return expression.argumentList;
    }
  }
  if (expression is MethodInvocation) {
    final method = expression.methodName.element;
    if (_inPackage(method) &&
        method?.enclosingElement?.name == 'ViewModelSpec' &&
        const {'arg', 'arg2', 'arg3', 'arg4'}.contains(method?.name)) {
      return expression.argumentList;
    }
  }
  return null;
}

Expression? _argument(ArgumentList arguments, String name) {
  for (final arg in arguments.arguments.whereType<NamedExpression>()) {
    if (arg.name.label.name == name) return arg.expression;
  }
  return null;
}

bool _isResolution(MethodInvocation node) =>
    const {'read', 'watch'}.contains(node.methodName.name) &&
    _inPackage(node.methodName.element) &&
    _isVm(node.staticType);

bool _ownBinding(MethodInvocation node) {
  final receiver = node.realTarget;
  if (receiver is SimpleIdentifier) {
    // Parsed imported getters have no elements; resolved local variables must
    // not be mistaken for the parent's dependency binding.
    return receiver.name == 'viewModelBinding' &&
        (receiver.element == null ||
            receiver.element is GetterElement && _inPackage(receiver.element));
  }
  return receiver is PropertyAccess &&
      receiver.realTarget is ThisExpression &&
      receiver.propertyName.name == 'viewModelBinding' &&
      (receiver.propertyName.element == null ||
          _inPackage(receiver.propertyName.element));
}

class _Visitor extends SimpleAstVisitor<void> {
  final ViewModelRule rule;
  final RuleContext context;
  late final _Dependencies dependencies = _Dependencies(context);

  _Visitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_inPackage(context.libraryElement)) return;
    _checkSpec(node);
    if (rule.kind == ViewModelRuleKind.unmanagedConstruction &&
        _isVm(node.staticType) &&
        !_managed(node)) {
      rule.reportAtNode(node);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_inPackage(context.libraryElement)) return;
    _checkSpec(node);
    if (!_isResolution(node)) return;
    if (rule.kind == ViewModelRuleKind.cachedInstance && _stored(node)) {
      rule.reportAtNode(node);
    }
    if (rule.kind == ViewModelRuleKind.dependencyCycle && _ownBinding(node)) {
      final owner = node
          .thisOrAncestorOfType<ClassDeclaration>()
          ?.declaredFragment
          ?.element;
      final target = node.staticType;
      if (owner == null || !_isVm(owner.thisType) || target is! InterfaceType) {
        return;
      }
      final path = dependencies.path(target.element, owner, {});
      if (path != null) {
        rule.reportAtNode(
          node,
          arguments: [
            [owner, ...path].map((e) => e.name).join(' -> '),
          ],
        );
      }
    }
  }

  void _checkSpec(Expression node) {
    final spec = _spec(node);
    if (spec == null) return;
    final key = _argument(spec, 'key');
    if (key != null && _literalResult(key) is! NullLiteral) return;
    if (rule.kind == ViewModelRuleKind.aliveForeverKey) {
      final alive = _literalResult(_argument(spec, 'aliveForever'));
      if (alive is BooleanLiteral && alive.value) rule.reportAtNode(node);
    }
  }

  bool _managed(InstanceCreationExpression node) {
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is FunctionExpression) {
        AstNode? argument = parent.parent;
        while (argument is ParenthesizedExpression) {
          argument = argument.parent;
        }
        if (argument is NamedExpression &&
            argument.name.label.name == 'builder') {
          final call = argument.parent?.parent;
          if (call is Expression && _spec(call) != null) return true;
        }
      }
      if (parent is MethodDeclaration) {
        final owner = parent
            .thisOrAncestorOfType<ClassDeclaration>()
            ?.declaredFragment
            ?.element;
        return parent.name.lexeme == 'build' &&
            !parent.isStatic &&
            parent.parameters?.parameters.isEmpty == true &&
            _hasType(owner?.thisType, 'ViewModelFactory');
      }
      if (parent is ConstructorDeclaration) {
        // @GenSpec may select the named factory `spec` as its managed builder.
        final owner = parent.thisOrAncestorOfType<ClassDeclaration>();
        return parent.factoryKeyword != null &&
            parent.name?.lexeme == 'spec' &&
            owner is ClassDeclaration &&
            owner.metadata.any(
              (annotation) =>
                  _inPackage(annotation.element, 'view_model_annotation') &&
                  annotation.element?.enclosingElement?.name == 'GenSpec',
            );
      }
      if (parent is ClassDeclaration) return false;
      parent = parent.parent;
    }
    return false;
  }

  bool _stored(MethodInvocation node) {
    AstNode child = node;
    while (child.parent is ParenthesizedExpression ||
        (child.parent is PostfixExpression &&
            (child.parent as PostfixExpression).operator.lexeme == '!')) {
      child = child.parent!;
    }
    final parent = child.parent;
    if (parent is VariableDeclaration && parent.initializer == child) {
      final declaration = parent.parent?.parent;
      return declaration is FieldDeclaration ||
          declaration is TopLevelVariableDeclaration;
    }
    if (parent is ConstructorFieldInitializer && parent.expression == child) {
      return true;
    }
    if (parent is AssignmentExpression && parent.rightHandSide == child) {
      final left = parent.leftHandSide;
      final element =
          parent.writeElement ??
          switch (left) {
            SimpleIdentifier() => left.element,
            PropertyAccess() => left.propertyName.element,
            PrefixedIdentifier() => left.identifier.element,
            _ => null,
          };
      if (element is PropertyAccessorElement) {
        // An explicit setter may transform its input instead of retaining it.
        // Keep analyzer 8 compatibility; isOriginVariable was added later.
        // ignore: deprecated_member_use
        return element.isSynthetic;
      }
      return element is FieldElement || element is TopLevelVariableElement;
    }
    return false;
  }
}

/// Per-analysis state never survives edits or leaks between packages.
class _Dependencies {
  final RuleContext context;
  final _edges = <InterfaceElement, Set<InterfaceElement>>{};
  final _parsed = <LibraryElement, ParsedLibraryResult?>{};

  _Dependencies(this.context) {
    for (final unit in context.allUnits) {
      unit.unit.accept(_EdgeVisitor(_edges));
    }
  }

  List<InterfaceElement>? path(
    InterfaceElement from,
    InterfaceElement to,
    Set<InterfaceElement> seen,
  ) {
    if (from == to) return [from];
    if (!seen.add(from)) return null;
    for (final next in _children(from)) {
      final tail = path(next, to, seen);
      if (tail != null) return [from, ...tail];
    }
    return null;
  }

  Set<InterfaceElement> _children(InterfaceElement type) => _edges.putIfAbsent(
    type,
    () {
      final children = <InterfaceElement>{};
      // A same-named getter overridden by an application is not the framework
      // dependency binding. Parsed bodies alone cannot resolve that receiver.
      final binding = type.lookUpGetter(
        name: 'viewModelBinding',
        library: type.library,
      );
      if (!_inPackage(binding)) return children;
      // Imported libraries have resolved signatures but no resolved bodies in
      // a synchronous lint callback. Follow only directly returned resolutions
      // in typed getters/fields; do not guess from arbitrary method names.
      final parsed = _parsed.putIfAbsent(type.library, () {
        final result = type.session?.getParsedLibraryByElement(type.library);
        return result is ParsedLibraryResult ? result : null;
      });
      if (parsed == null) return children;
      for (final getter in type.getters.where((g) => !g.isStatic)) {
        final resultType = getter.returnType;
        if (!_isVm(resultType) || resultType is! InterfaceType) continue;
        // Keep analyzer 8 compatibility; isOriginVariable was added later.
        // ignore: deprecated_member_use
        final Fragment fragment = getter.isSynthetic
            ? getter.variable.firstFragment
            : getter.firstFragment;
        final declaration = parsed.getFragmentDeclaration(fragment)?.node;
        Expression? value;
        if (declaration is MethodDeclaration) {
          final body = declaration.body;
          if (body is ExpressionFunctionBody) value = body.expression;
          if (body is BlockFunctionBody && body.block.statements.length == 1) {
            final statement = body.block.statements.single;
            if (statement is ReturnStatement) value = statement.expression;
          }
        } else if (declaration is VariableDeclaration) {
          value = declaration.initializer;
        }
        if (value != null) value = _unwrap(value);
        if (value is MethodInvocation &&
            _ownBinding(value) &&
            const {'read', 'watch'}.contains(value.methodName.name)) {
          children.add(resultType.element);
        }
      }
      return children;
    },
  );
}

class _EdgeVisitor extends RecursiveAstVisitor<void> {
  final Map<InterfaceElement, Set<InterfaceElement>> edges;
  _EdgeVisitor(this.edges);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isResolution(node) && _ownBinding(node)) {
      final owner = node
          .thisOrAncestorOfType<ClassDeclaration>()
          ?.declaredFragment
          ?.element;
      final target = node.staticType;
      if (owner != null && _isVm(owner.thisType) && target is InterfaceType) {
        edges.putIfAbsent(owner, () => {}).add(target.element);
      }
    }
    super.visitMethodInvocation(node);
  }
}
