import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

part 'fixes.dart';

enum ViewModelRuleKind {
  dependencyCycle,
  cachedInstance,
  aliveForeverKey,
  unmanagedConstruction,
  listenInBuild,
  instanceHandoff,
  identityCollision,
  selectorWithWatch,
  undisposedBinding,
  temporarySpec,
  cachedLookup;

  /// Opt-in kinds are registered as lints, which stay off until enabled.
  bool get optIn => this == cachedLookup;
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
  ViewModelRuleKind.listenInBuild: LintCode(
    'view_model_listen_in_build',
    'This listener is registered again every time this member runs.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Register listen/listenState/listenStateSelect once, '
        'for example in initState or onCreate.',
  ),
  ViewModelRuleKind.instanceHandoff: LintCode(
    'view_model_instance_handoff',
    'A ViewModel passed through a constructor bypasses binding ownership.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Pass a spec, key, or plain data and resolve the '
        "ViewModel through the receiver's binding.",
  ),
  ViewModelRuleKind.identityCollision: LintCode(
    'view_model_identity_collision',
    'Unkeyed {0} resolutions in one binding share a single instance.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Add a key that identifies each instance, for example '
        'one derived from the spec argument.',
  ),
  ViewModelRuleKind.selectorWithWatch: LintCode(
    'view_model_selector_with_watch',
    'A watched ViewModel rebuilds the whole owner and defeats the selectors.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Resolve this ViewModel with read and let the selectors '
        'drive rebuilds.',
  ),
  ViewModelRuleKind.undisposedBinding: LintCode(
    'view_model_undisposed_binding',
    'This ViewModelBinding is never disposed, so its ViewModels stay bound.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Call dispose() when the owner finishes, for example '
        'in tearDown or addTearDown.',
  ),
  ViewModelRuleKind.temporarySpec: LintCode(
    'view_model_temporary_spec',
    'A spec or factory must be a top-level or static variable, not a '
        'temporary value.',
    severity: DiagnosticSeverity.WARNING,
    correctionMessage:
        'Declare it once as a top-level or static final and '
        'reuse that variable.',
  ),
  ViewModelRuleKind.cachedLookup: LintCode(
    'view_model_cached_lookup',
    'A cached lookup only finds an instance that another owner created.',
    severity: DiagnosticSeverity.INFO,
    correctionMessage:
        'Resolve a stable spec with watch/read unless this '
        'cross-owner query is intentional.',
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
    if (kind == ViewModelRuleKind.instanceHandoff) {
      registry.addConstructorDeclaration(this, visitor);
    }
  }
}

/// Create-or-get resolutions, including the host compatibility extensions.
const _resolveMethods = {'read', 'watch', 'readViewModel', 'watchViewModel'};

/// Calls that listen to the resolved ViewModel's own notifications.
const _watchMethods = {
  'watch',
  'watchViewModel',
  'watchCached',
  'maybeWatchCached',
  'watchCachedViewModel',
  'maybeWatchCachedViewModel',
};

/// Lookup-only queries that can never create the instance they return.
const _cachedMethods = {
  'readCached',
  'watchCached',
  'maybeReadCached',
  'maybeWatchCached',
  'readCachesByTag',
  'watchCachesByTag',
  'readCachedViewModel',
  'watchCachedViewModel',
  'maybeReadCachedViewModel',
  'maybeWatchCachedViewModel',
};

/// Binding, host-extension, and instance listener registrations.
const _listenMethods = {
  'listen',
  'listenState',
  'listenStateSelect',
  'listenViewModel',
  'listenViewModelState',
  'listenViewModelStateSelect',
};

const _specClasses = {
  'ViewModelSpec',
  'ViewModelProvider',
  'ViewModelSpecWithArg',
  'ViewModelSpecWithArg2',
  'ViewModelSpecWithArg3',
  'ViewModelSpecWithArg4',
};

const _argSpecMethods = {'arg', 'arg2', 'arg3', 'arg4'};

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

bool _calls(MethodInvocation node, Set<String> names) =>
    names.contains(node.methodName.name) && _inPackage(node.methodName.element);

bool _constructs(InstanceCreationExpression node, String name) {
  final type = node.constructorName.element?.enclosingElement;
  return type is InterfaceElement && _isType(type, name);
}

Expression _unwrap(Expression expression) =>
    expression is ParenthesizedExpression
    ? _unwrap(expression.expression)
    : expression;

Expression? _returned(FunctionBody body) {
  if (body is ExpressionFunctionBody) return body.expression;
  if (body is BlockFunctionBody && body.block.statements.length == 1) {
    final statement = body.block.statements.single;
    if (statement is ReturnStatement) return statement.expression;
  }
  return null;
}

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
    if (_specClasses.contains(element.name)) return expression.argumentList;
  }
  if (expression is MethodInvocation) {
    final method = expression.methodName.element;
    if (_inPackage(method) &&
        method?.enclosingElement?.name == 'ViewModelSpec' &&
        _argSpecMethods.contains(method?.name)) {
      return expression.argumentList;
    }
  }
  return null;
}

/// Arguments of a spec construction in a parsed, unresolved declaration.
/// Callers have already proved from the declared type that it is a spec.
ArgumentList? _parsedSpec(Expression? expression) {
  if (expression == null) return null;
  expression = _unwrap(expression);
  final String callee;
  final ArgumentList arguments;
  if (expression is InstanceCreationExpression) {
    callee = expression.constructorName.toSource();
    arguments = expression.argumentList;
  } else if (expression is MethodInvocation) {
    final target = expression.target;
    callee = target == null
        ? expression.methodName.name
        : '${target.toSource()}.${expression.methodName.name}';
    arguments = expression.argumentList;
  } else {
    return null;
  }
  final segments = callee.replaceAll(RegExp('<.*>'), '').split('.');
  final last = segments.last;
  final recognized =
      _specClasses.contains(last) ||
      segments.length > 1 &&
          segments[segments.length - 2] == 'ViewModelSpec' &&
          _argSpecMethods.contains(last);
  return recognized ? arguments : null;
}

Expression? _argument(ArgumentList arguments, String name) {
  for (final arg in arguments.arguments.whereType<NamedExpression>()) {
    if (arg.name.label.name == name) return arg.expression;
  }
  return null;
}

/// The spec a framework resolution or binding listener consumes.
Expression? _factoryOf(MethodInvocation node) {
  final named = _argument(node.argumentList, 'factory');
  if (named != null) return _unwrap(named);
  final arguments = node.argumentList.arguments;
  if (arguments.isEmpty || arguments.first is NamedExpression) return null;
  return _unwrap(arguments.first);
}

/// The variable or explicit getter that an identifier-like expression reads.
Element? _readElement(Expression? expression) {
  if (expression == null) return null;
  final element = switch (_unwrap(expression)) {
    SimpleIdentifier(:final element) => element,
    PrefixedIdentifier(:final identifier) => identifier.element,
    PropertyAccess(:final propertyName) => propertyName.element,
    _ => null,
  }?.baseElement;
  // Keep analyzer 8 compatibility; isOriginVariable was added later.
  // ignore: deprecated_member_use
  if (element is PropertyAccessorElement && element.isSynthetic) {
    return element.variable.baseElement;
  }
  return element;
}

InterfaceElement? _enclosingType(AstNode node) {
  final declaration = node.thisOrAncestorMatching(
    (node) => node is ClassDeclaration || node is MixinDeclaration,
  );
  if (declaration is ClassDeclaration) {
    return declaration.declaredFragment?.element;
  }
  if (declaration is MixinDeclaration) {
    return declaration.declaredFragment?.element;
  }
  return null;
}

bool _isResolution(MethodInvocation node) =>
    const {'read', 'watch'}.contains(node.methodName.name) &&
    _inPackage(node.methodName.element) &&
    _isVm(node.staticType);

/// A call whose single ViewModel result must not outlive the expression.
bool _isRetainable(MethodInvocation node) =>
    (_calls(node, _resolveMethods) || _calls(node, _cachedMethods)) &&
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

/// Whether [node] runs directly in a member that executes on every build,
/// refresh request, or getter access. Closures run on their own schedule.
bool _isRepeated(AstNode node) {
  var member = node.thisOrAncestorOfType<FunctionBody>()?.parent;
  if (member is FunctionExpression) member = member.parent;
  if (member is FunctionDeclaration) return member.isGetter;
  if (member is! MethodDeclaration) return false;
  if (member.isGetter) return true;
  final owner = _enclosingType(member)?.thisType;
  return switch (member.name.lexeme) {
    'build' || 'didUpdateWidget' || 'didChangeDependencies' =>
      _hasType(owner, 'ViewModelStateMixin') ||
          _hasType(owner, 'ViewModelStatelessMixin'),
    'onUpdate' => _hasType(owner, 'ViewModelBinding'),
    _ => false,
  };
}

/// Whether a spec or factory construction is the single program-wide
/// declaration of that spec: the initializer of a top-level variable or static field. Dart
/// has no generic variables, so a generic function or static method whose
/// body only returns the spec, as generated for generic ViewModels, is also
/// accepted. A replacement passed straight to `setProxy` is reached only
/// through the stable spec it overrides.
bool _isStableSpec(Expression node) {
  AstNode child = node;
  while (child.parent is ParenthesizedExpression) {
    child = child.parent!;
  }
  final parent = child.parent;
  if (parent is VariableDeclaration && parent.initializer == child) {
    final declaration = parent.parent?.parent;
    return declaration is TopLevelVariableDeclaration ||
        declaration is FieldDeclaration && declaration.isStatic;
  }
  if (parent is ArgumentList) {
    final call = parent.parent;
    return call is MethodInvocation && _calls(call, const {'setProxy'});
  }
  final body = child.thisOrAncestorOfType<FunctionBody>();
  if (body == null || _returned(body) != child) return false;
  final owner = body.parent;
  if (owner is MethodDeclaration) {
    return owner.isStatic && owner.typeParameters != null;
  }
  return owner is FunctionExpression &&
      owner.typeParameters != null &&
      owner.parent is FunctionDeclaration &&
      owner.parent?.parent is CompilationUnit;
}

class _Visitor extends SimpleAstVisitor<void> {
  final ViewModelRule rule;
  final RuleContext context;
  late final dependencies = _Dependencies(context);
  late final values = _Values.of(context);
  late final collisions = _Collisions(context).sites;

  _Visitor(this.rule, this.context);

  bool get _isFramework => _inPackage(context.libraryElement);

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if (_isFramework) return;
    for (var parameter in node.parameters.parameters) {
      if (parameter is DefaultFormalParameter) parameter = parameter.parameter;
      // A super parameter is reported where the super constructor declares it.
      if (parameter is SuperFormalParameter) continue;
      if (_isVm(parameter.declaredFragment?.element.type)) {
        rule.reportAtNode(parameter);
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isFramework) return;
    switch (rule.kind) {
      case ViewModelRuleKind.aliveForeverKey:
        _checkSpec(node);
      case ViewModelRuleKind.unmanagedConstruction:
        if (_isVm(node.staticType) && !_managed(node)) rule.reportAtNode(node);
      case ViewModelRuleKind.selectorWithWatch:
        final viewModel = _argument(node.argumentList, 'viewModel');
        if (viewModel != null &&
            _constructs(node, 'StateViewModelValueWatcher') &&
            _isWatched(viewModel)) {
          rule.reportAtNode(viewModel);
        }
      case ViewModelRuleKind.undisposedBinding:
        if (_hasType(node.staticType, 'ViewModelBinding') &&
            _isUndisposed(node)) {
          rule.reportAtNode(node);
        }
      case ViewModelRuleKind.temporarySpec:
        // Custom ViewModelFactory classes are specs in the same sense.
        if ((_spec(node) != null ||
                _hasType(node.staticType, 'ViewModelFactory')) &&
            !_isStableSpec(node)) {
          rule.reportAtNode(node);
        }
      case ViewModelRuleKind.dependencyCycle:
      case ViewModelRuleKind.cachedInstance:
      case ViewModelRuleKind.listenInBuild:
      case ViewModelRuleKind.instanceHandoff:
      case ViewModelRuleKind.identityCollision:
      case ViewModelRuleKind.cachedLookup:
        break;
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isFramework) return;
    switch (rule.kind) {
      case ViewModelRuleKind.aliveForeverKey:
        _checkSpec(node);
      case ViewModelRuleKind.cachedInstance:
        if (_isRetainable(node) && _stored(node)) rule.reportAtNode(node);
      case ViewModelRuleKind.dependencyCycle:
        if (_isResolution(node) && _ownBinding(node)) _checkCycle(node);
      case ViewModelRuleKind.listenInBuild:
        if (_calls(node, _listenMethods) && _isRepeated(node)) {
          rule.reportAtNode(node);
        }
      case ViewModelRuleKind.identityCollision:
        if (collisions[node] case final type?) {
          rule.reportAtNode(node, arguments: [type]);
        }
      case ViewModelRuleKind.temporarySpec:
        if (_spec(node) != null && !_isStableSpec(node)) {
          rule.reportAtNode(node);
        }
      case ViewModelRuleKind.cachedLookup:
        if (_calls(node, _cachedMethods)) rule.reportAtNode(node);
      case ViewModelRuleKind.unmanagedConstruction:
      case ViewModelRuleKind.instanceHandoff:
      case ViewModelRuleKind.selectorWithWatch:
      case ViewModelRuleKind.undisposedBinding:
        break;
    }
  }

  void _checkCycle(MethodInvocation node) {
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

  void _checkSpec(Expression node) {
    final spec = _spec(node);
    if (spec == null) return;
    final key = _argument(spec, 'key');
    if (key != null && _literalResult(key) is! NullLiteral) return;
    final alive = _literalResult(_argument(spec, 'aliveForever'));
    if (alive is BooleanLiteral && alive.value) rule.reportAtNode(node);
  }

  /// Follows a short chain of final variables and getters to a watch call.
  bool _isWatched(Expression expression, [int depth = 0]) {
    expression = _unwrap(expression);
    if (expression is PostfixExpression &&
        expression.operator.type == TokenType.BANG) {
      return _isWatched(expression.operand, depth);
    }
    if (expression is MethodInvocation) {
      return _calls(expression, _watchMethods);
    }
    final value = values[_readElement(expression)];
    return value != null && depth < 3 && _isWatched(value, depth + 1);
  }

  /// Whether a created binding reaches no dispose call and no other owner.
  bool _isUndisposed(InstanceCreationExpression node) {
    Expression created = node;
    var parent = created.parent;
    while (parent is ParenthesizedExpression) {
      created = parent;
      parent = parent.parent;
    }
    if (parent is CascadeExpression && parent.target == created) {
      if (parent.cascadeSections.any(_isDispose)) return false;
      created = parent;
      parent = parent.parent;
    }
    final Element? holder;
    if (parent is VariableDeclaration && parent.initializer == created) {
      holder = parent.declaredFragment?.element.baseElement;
    } else if (parent is AssignmentExpression &&
        parent.rightHandSide == created &&
        parent.operator.type == TokenType.EQ) {
      holder = _written(parent);
    } else {
      // A temporary such as `ViewModelBinding().read(spec)` cannot be
      // disposed later; any other use hands the binding to a new owner.
      return parent is ExpressionStatement ||
          parent is MethodInvocation &&
              parent.target == created &&
              parent.methodName.name != 'dispose' ||
          parent is PropertyAccess && parent.target == created;
    }
    if (holder == null) return false;
    final usage = _BindingUsage(holder);
    for (final unit in context.allUnits) {
      unit.unit.accept(usage);
    }
    return !usage.disposed && !usage.escaped;
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

bool _isDispose(Expression section) =>
    section is MethodInvocation && section.methodName.name == 'dispose';

/// The variable an assignment writes, normalized like [_readElement].
Element? _written(AssignmentExpression node) {
  final element = node.writeElement?.baseElement;
  // Keep analyzer 8 compatibility; isOriginVariable was added later.
  // ignore: deprecated_member_use
  if (element is PropertyAccessorElement && element.isSynthetic) {
    return element.variable.baseElement;
  }
  return element ?? _readElement(node.leftHandSide);
}

/// Records whether a binding variable is disposed or handed to a new owner.
class _BindingUsage extends RecursiveAstVisitor<void> {
  final Element holder;
  bool disposed = false;
  bool escaped = false;

  _BindingUsage(this.holder);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_readElement(node) != holder) return;
    Expression reference = node;
    final access = node.parent;
    if (access is PropertyAccess && access.propertyName == node ||
        access is PrefixedIdentifier && access.identifier == node) {
      reference = access as Expression;
    }
    final parent = reference.parent;
    if (parent is MethodInvocation && parent.target == reference) {
      if (parent.methodName.name == 'dispose') disposed = true;
    } else if (parent is PrefixedIdentifier && parent.prefix == reference) {
      // A tear-off such as `addTearDown(binding.dispose)`.
      if (parent.identifier.name == 'dispose') disposed = true;
    } else if (parent is PropertyAccess && parent.target == reference) {
      if (parent.propertyName.name == 'dispose') disposed = true;
    } else if (parent is CascadeExpression && parent.target == reference) {
      if (parent.cascadeSections.any(_isDispose)) disposed = true;
    } else if (parent is ArgumentList ||
        parent is NamedExpression ||
        parent is ReturnStatement ||
        parent is ExpressionFunctionBody ||
        parent is VariableDeclaration ||
        parent is ListLiteral ||
        parent is SetOrMapLiteral ||
        parent is MapLiteralEntry ||
        parent is AssignmentExpression && parent.rightHandSide == reference) {
      escaped = true;
    }
  }
}

/// Values of final variables and single-expression getters in this library.
class _Values extends RecursiveAstVisitor<void> {
  final values = <Element, Expression>{};

  static Map<Element, Expression> of(RuleContext context) {
    final visitor = _Values();
    for (final unit in context.allUnits) {
      unit.unit.accept(visitor);
    }
    return visitor.values;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final element = node.declaredFragment?.element;
    final initializer = node.initializer;
    if (element != null &&
        initializer != null &&
        (node.isFinal || node.isConst)) {
      values[element.baseElement] = initializer;
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isGetter) _getter(node.declaredFragment?.element, node.body);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.isGetter) {
      _getter(node.declaredFragment?.element, node.functionExpression.body);
    }
    super.visitFunctionDeclaration(node);
  }

  void _getter(Element? element, FunctionBody body) {
    final value = _returned(body);
    if (element != null && value != null) values[element.baseElement] = value;
  }
}

/// Unkeyed resolutions that silently reuse another instance in one binding.
///
/// Identity is the resolved type plus key, so within one binding every
/// unkeyed resolution of a type returns the first instance created. Two
/// different specs, or one parameterized spec called with different
/// arguments, therefore collide. A site whose argument reads a variable
/// declared in an enclosing loop, closure, or method parameter collides
/// with itself.
class _Collisions {
  final RuleContext context;
  final _keys = _SpecKeys();
  final sites = <MethodInvocation, String>{};

  _Collisions(this.context) {
    final groups =
        <(Element, InterfaceElement), List<(MethodInvocation, Object, bool)>>{};
    void visit(MethodInvocation node) {
      if (!_calls(node, _resolveMethods)) return;
      final type = node.staticType;
      final scope = _bindingScope(node);
      final factory = _factoryOf(node);
      if (type is! InterfaceType || scope == null || factory == null) return;
      final Element? spec;
      ArgumentList? arguments;
      if (factory is FunctionExpressionInvocation) {
        spec = _readElement(factory.function);
        arguments = factory.argumentList;
      } else {
        spec = _readElement(factory);
      }
      if (spec == null || !_keys.isUnkeyed(spec)) return;
      groups.putIfAbsent((scope, type.element), () => []).add((
        node,
        (spec, arguments?.toSource()),
        arguments != null && _varies(arguments),
      ));
    }

    context.currentUnit?.unit.accept(_Invocations(visit));
    for (final MapEntry(key: (_, type), value: group) in groups.entries) {
      final first = group.first.$2;
      for (final (node, signature, varies) in group) {
        if (varies || signature != first) sites[node] = type.displayName;
      }
    }
  }

  /// The binding a resolution goes through: one owner type for its own
  /// binding, or a variable that holds a binding. Other receivers can hold
  /// different bindings per object and are skipped.
  static Element? _bindingScope(MethodInvocation node) {
    final target = node.realTarget;
    if (target == null || _ownBinding(node)) return _enclosingType(node);
    if (_unwrap(target) is! SimpleIdentifier) return null;
    final element = _readElement(target);
    return element is VariableElement && !_inPackage(element) ? element : null;
  }

  static bool _varies(ArgumentList arguments) {
    final used = <Element>{};
    arguments.accept(_Locals(used));
    if (used.isEmpty) return false;
    for (AstNode? node = arguments.parent; node != null; node = node.parent) {
      if (node is MethodDeclaration ||
          node is FunctionDeclaration ||
          node is ConstructorDeclaration) {
        // A `build` context is fixed per owner; other parameters vary by call.
        final parameters = switch (node) {
          MethodDeclaration() when node.name.lexeme != 'build' =>
            node.parameters,
          FunctionDeclaration() => node.functionExpression.parameters,
          _ => null,
        };
        final declared = <Element>{};
        parameters?.accept(_Declared(declared));
        return used.any(declared.contains);
      }
      if (node is ClassDeclaration || node is CompilationUnit) return false;
      if (node is ForStatement ||
          node is ForElement ||
          node is WhileStatement ||
          node is DoStatement ||
          node is FunctionExpression) {
        final declared = <Element>{};
        node.accept(_Declared(declared));
        if (used.any(declared.contains)) return true;
      }
    }
    return false;
  }
}

class _Invocations extends RecursiveAstVisitor<void> {
  final void Function(MethodInvocation node) onInvocation;
  _Invocations(this.onInvocation);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onInvocation(node);
    super.visitMethodInvocation(node);
  }
}

class _Locals extends RecursiveAstVisitor<void> {
  final Set<Element> elements;
  _Locals(this.elements);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element is LocalVariableElement || element is FormalParameterElement) {
      elements.add(element!.baseElement);
    }
  }
}

class _Declared extends RecursiveAstVisitor<void> {
  final Set<Element> elements;
  _Declared(this.elements);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _add(node.declaredFragment?.element);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    _add(node.declaredFragment?.element);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (final parameter in node.parameters) {
      _add(parameter.declaredFragment?.element);
    }
    super.visitFormalParameterList(node);
  }

  void _add(Element? element) {
    if (element != null) elements.add(element.baseElement);
  }
}

/// Reads spec declarations, including imported ones, to learn whether they
/// set a key. Unknown initializers are never guessed to be unkeyed.
class _SpecKeys {
  final _parsed = <LibraryElement, ParsedLibraryResult?>{};
  final _unkeyed = <Element, bool>{};

  bool isUnkeyed(Element element) => _unkeyed.putIfAbsent(element, () {
    if (element is! TopLevelVariableElement && element is! FieldElement) {
      return false;
    }
    final variable = element as VariableElement;
    final library = variable.library;
    if (!(variable.isFinal || variable.isConst) ||
        library == null ||
        !_specClasses.any((name) => _hasType(variable.type, name))) {
      return false;
    }
    final parsed = _parsed.putIfAbsent(library, () {
      final result = variable.session?.getParsedLibraryByElement(library);
      return result is ParsedLibraryResult ? result : null;
    });
    final declaration = parsed
        ?.getFragmentDeclaration(variable.firstFragment)
        ?.node;
    if (declaration is! VariableDeclaration) return false;
    final arguments = _parsedSpec(declaration.initializer);
    if (arguments == null) return false;
    final key = _argument(arguments, 'key');
    return key == null || _literalResult(key) is NullLiteral;
  });
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
          value = _returned(declaration.body);
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
