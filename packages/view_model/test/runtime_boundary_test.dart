import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/get_instance/store.dart';
import 'package:view_model/src/view_model/binding_zone.dart';
import 'package:view_model/src/view_model/model.dart' as legacy_model;
import 'package:view_model/src/view_model/pause_aware.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/view_model.dart';

class _Vm with ViewModel {
  _Vm(
      {this.created,
      this.bound,
      this.unbound,
      Object? cleanupError,
      this.listenerCleanupError,
      this.disposed}) {
    if (cleanupError != null) addDispose(() => throw cleanupError);
  }
  final void Function(_Vm)? created;
  final void Function(_Vm, String)? bound;
  final void Function(_Vm, String)? unbound;
  final Object? listenerCleanupError;
  final VoidCallback? disposed;
  ViewModelBindingInterface get legacyBinding => vef;
  ViewModelBindingInterface get dependencies => viewModelBinding;
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    created?.call(this);
  }

  @override
  void onBind(InstanceArg arg, String id) {
    super.onBind(arg, id);
    bound?.call(this, id);
  }

  @override
  void onUnbind(InstanceArg arg, String id) {
    super.onUnbind(arg, id);
    unbound?.call(this, id);
  }

  @override
  Function() listen({required VoidCallback onChanged}) {
    final remove = super.listen(onChanged: onChanged);
    return () {
      remove();
      if (listenerCleanupError != null) throw listenerCleanupError!;
    };
  }

  @override
  void dispose() {
    super.dispose();
    disposed?.call();
  }
}

class _Owner<T extends ViewModel> extends ViewModelBinding {
  _Owner(this.spec);
  final ViewModelFactory<T> spec;
  T get vm => read(spec);
  T get watched => watch(spec);
  bool get legacyBindingMatches => identical(vef, viewModelBinding);
}

class _Observer extends ViewModelLifecycle {
  _Observer(this.events);
  final List<String> events;
  @override
  void onBind(ViewModel vm, InstanceArg arg, String id) {
    events.add('bind');
    throw StateError('observer bind');
  }

  @override
  void onUnbind(ViewModel vm, InstanceArg arg, String id) {
    events.add('unbind');
    throw StateError('observer unbind');
  }

  @override
  void onDispose(ViewModel vm, InstanceArg arg) {
    events.add('dispose');
    throw StateError('observer dispose');
  }
}

class _RefHandler extends ViewModelBindingHandler {
  _RefHandler({this.removeError, this.disposeError});
  final Object? removeError;
  final Object? disposeError;
  @override
  void Function() addOwnerChangeListener(ViewModelOwnersChanged listener) {
    final remove = super.addOwnerChangeListener(listener);
    return () {
      remove();
      if (removeError != null) throw removeError!;
    };
  }

  @override
  void dispose() {
    super.dispose();
    if (disposeError != null) throw disposeError!;
  }
}

class _RefVm extends _Vm {
  _RefVm(this._handler, {super.disposed});
  final ViewModelBindingHandler _handler;
  @override
  ViewModelBindingHandler get refHandler => _handler;
}

class _FailingPauseController extends PauseAwareController {
  _FailingPauseController()
      : super(onWidgetPause: () {}, onWidgetResume: () {}, providers: []);
  @override
  void dispose() {
    super.dispose();
    throw StateError('pause controller cleanup');
  }
}

class _PauseOwner extends _Owner<_Vm> {
  _PauseOwner(super.spec);
  @override
  PauseAwareController createPauseController() => _FailingPauseController();
}

class _StaleStatusOwner extends _Owner<_Vm> {
  _StaleStatusOwner(super.spec);
  @override
  bool get isDisposed => false;
}

class _Resource implements InstanceLifeCycle {
  _Resource({this.disposed});
  final VoidCallback? disposed;
  @override
  void onCreate(InstanceArg arg) {}
  @override
  void onBind(InstanceArg arg, String id) {}
  @override
  void onUnbind(InstanceArg arg, String id) {}
  @override
  void onDispose(InstanceArg arg) => disposed?.call();
}

void main() {
  final errors = <(Object, ErrorType)>[];
  late DebugPrintCallback originalPrint;
  setUp(() {
    ViewModel.reset();
    originalPrint = debugPrint;
    errors.clear();
    ViewModel.initialize(
        config: ViewModelConfig(
      onError: (error, _, type) => errors.add((error, type)),
    ));
  });
  tearDown(() {
    debugPrint = originalPrint;
    ViewModel.reset();
  });
  // A failed error sink must not bypass the enclosing cleanup boundary.
  void failErrorReporting(int failures) {
    ViewModel.reset();
    ViewModel.initialize(config: ViewModelConfig(
      onError: (error, _, type) {
        errors.add((error, type));
        if (failures > 0) throw StateError('error handler failed');
      },
    ));
    debugPrint = (message, {wrapWidth}) {
      if (failures-- > 0) throw StateError('log sink failed');
    };
  }

  test('legacy accessors and providers preserve binding identity', () {
    final owner = _Owner(ViewModelProvider<_Vm>(builder: _Vm.new));
    addTearDown(owner.dispose);
    expect(owner.legacyBindingMatches, isTrue);
    expect(owner.vm.legacyBinding, same(owner.vm.dependencies));
    expect(owner.getName(), contains('_Owner'));
  });

  test('legacy dependency metadata preserves the spec without resolving it',
      () {
    var built = false;
    final spec = ViewModelSpec<_Vm>(builder: () {
      built = true;
      return _Vm();
    });
    final config = legacy_model.ViewModelConfig<_Vm>(
      key: 'legacy-key',
      tag: 'legacy-tag',
      factory: spec,
    );
    final dependency = legacy_model.ViewModelDependencyConfig(config: config);
    expect(dependency.config, same(config));
    expect(config.key, 'legacy-key');
    expect(config.tag, 'legacy-tag');
    expect(config.factory, same(spec));
    expect(config.toString(),
        '_Vm {key: legacy-key, tag: legacy-tag, factory: $spec}');
    expect(built, isFalse);
  });

  test('a custom status getter cannot bypass the internal disposal guard', () {
    var built = false;
    final owner = _StaleStatusOwner(ViewModelSpec(builder: () {
      built = true;
      return _Vm();
    }));
    addTearDown(owner.dispose);
    owner.dispose();
    expect(() => owner.vm, throwsA(isA<ViewModelError>()));
    expect(built, isFalse);
  });

  test('lifecycle observer failures do not prevent release or disposal', () {
    final events = <String>[];
    ViewModel.reset();
    ViewModel.initialize(
      config: ViewModelConfig(
        onError: (error, _, type) => errors.add((error, type)),
      ),
      lifecycles: [_Observer(events)],
    );
    final owner = _Owner(ViewModelSpec<_Vm>(
      builder: () => _Vm(disposed: () => events.add('resource disposed')),
    ));
    addTearDown(owner.dispose);
    owner.vm;
    owner.dispose();
    expect(events, ['bind', 'unbind', 'resource disposed', 'dispose']);
    expect(errors.map((e) => e.$2),
        [ErrorType.lifecycle, ErrorType.lifecycle, ErrorType.dispose]);
  });

  test('a failing resource error sink does not skip ViewModel disposal', () {
    failErrorReporting(1);
    var disposed = false;
    final owner = _Owner(ViewModelSpec<_Vm>(
        builder: () => _Vm(
              cleanupError: StateError('resource cleanup'),
              disposed: () => disposed = true,
            )));
    addTearDown(owner.dispose);
    owner.vm;
    owner.dispose();
    expect(disposed, isTrue);
    expect(errors.map((e) => e.$1.toString()), [
      contains('resource cleanup'),
      contains('log sink failed'),
    ]);
  });

  for (final boundary in ['dependency listener', 'owner handler']) {
    test('$boundary failure does not skip remaining ViewModel cleanup', () {
      var disposed = false;
      final failure = StateError(boundary);
      final owner = _Owner(ViewModelSpec<_RefVm>(
          builder: () => _RefVm(
                _RefHandler(
                  removeError:
                      boundary == 'dependency listener' ? failure : null,
                  disposeError: boundary == 'owner handler' ? failure : null,
                ),
                disposed: () => disposed = true,
              )));
      addTearDown(owner.dispose);
      owner.vm.dependencies;
      owner.dispose();
      expect(disposed, isTrue);
      expect(errors, [(failure, ErrorType.dispose)]);
    });
  }

  for (final watch in [false, true]) {
    test('throwing subscription cleanup watch=$watch still releases owners',
        () {
      var disposed = false;
      final failure = StateError('subscription cleanup');
      final owner = _Owner(ViewModelSpec<_Vm>(
          builder: () => _Vm(
                listenerCleanupError: failure,
                disposed: () => disposed = true,
              )));
      addTearDown(owner.dispose);
      if (watch) {
        owner.watched;
      } else {
        owner.listen(owner.spec, onChanged: () {});
      }
      owner.dispose();
      expect(disposed, isTrue);
      expect(errors, [(failure, ErrorType.dispose)]);
    });
  }

  test('pause controller failure still releases owned instances', () {
    var disposed = false;
    final owner = _PauseOwner(ViewModelSpec<_Vm>(
      builder: () => _Vm(disposed: () => disposed = true),
    ));
    addTearDown(owner.dispose);
    expect(owner.isPaused, isFalse);
    owner.vm;
    owner.dispose();
    expect(disposed, isTrue);
    expect(errors.single.$1.toString(), contains('pause controller cleanup'));
  });

  test('instance cleanup reporting failures do not escape binding disposal',
      () {
    failErrorReporting(2);
    final owner = _Owner(ViewModelSpec<_Vm>(
        builder: () => _Vm(
              unbound: (_, __) => throw StateError('unbind failed'),
            )));
    addTearDown(owner.dispose);
    owner.vm;
    expect(owner.dispose, returnsNormally);
    expect(owner.isDisposed, isTrue);
    expect(errors.map((e) => e.$2),
        [ErrorType.lifecycle, ErrorType.dispose, ErrorType.dispose]);
    expect(errors.last.$1.toString(), contains('log sink failed'));
  });

  test('reset from onCreate rejects and disposes the uncached generation', () {
    var disposed = false;
    final owner = _Owner(ViewModelSpec<_Vm>(
        builder: () => _Vm(
              created: (_) => ViewModel.reset(),
              disposed: () => disposed = true,
            )));
    addTearDown(owner.dispose);
    expect(() => owner.vm, throwsA(isA<ViewModelError>()));
    expect(disposed, isTrue);
    expect(instanceManager.debugStoreCount, 0);
  });

  test('onBind errors are reported without discarding committed ownership', () {
    final failure = StateError('bind failed');
    final owner = _Owner(ViewModelSpec<_Vm>(
      builder: () => _Vm(bound: (_, __) => throw failure),
      key: 'binding-failure',
    ));
    final guest = ViewModelBinding();
    addTearDown(owner.dispose);
    addTearDown(guest.dispose);
    expect(owner.vm.refHandler.owners, [owner]);
    expect(errors, [(failure, ErrorType.lifecycle)]);
    final handle = instanceManager.getNotifier<_Vm>();
    expect(handle.toString(), contains('binding-failure'));
    guest.dispose();
    expect(() => handle.bindOwner(guest), throwsA(isA<ViewModelError>()));
    owner.dispose();
    expect(() => handle.bindOwner(owner), throwsA(isA<ViewModelError>()));
  });

  test('latest lookup invokes onResolve and tag lookup rejects dynamic', () {
    final owner = _Owner(ViewModelSpec<_Vm>(builder: _Vm.new));
    addTearDown(owner.dispose);
    owner.vm;
    var resolved = false;
    final handle = instanceManager.getNotifier<_Vm>(onResolve: (handle) {
      resolved = true;
      expect(handle.instance.refHandler.owners, [owner]);
    });
    expect(resolved, isTrue);
    expect(handle.instance, same(owner.vm));
    expect(() => instanceManager.getNotifiersByTag<dynamic>('any'),
        throwsA(isA<ViewModelError>()));
  });

  test('disposed Store rejects every lookup without running a builder', () {
    final store = Store<_Resource>()..dispose();
    var built = false;
    expect(store.findNewlyInstance, throwsA(isA<ViewModelError>()));
    expect(
        () => store.getInstancesByTag('tag'), throwsA(isA<ViewModelError>()));
    expect(
        () => store.getNotifier(
                factory: InstanceFactory(
              arg: const InstanceArg(key: 'new'),
              builder: () {
                built = true;
                return _Resource();
              },
            )),
        throwsA(isA<ViewModelError>()));
    expect(built, isFalse);
  });

  test('Store reports uncached cleanup errors and preserves creation failure',
      () {
    final store = Store<_Resource>();
    final failure = StateError('uncached cleanup');
    expect(
        () => store.getNotifier(
                factory: InstanceFactory(
              arg: const InstanceArg(key: 'new'),
              builder: () {
                store.dispose();
                return _Resource(disposed: () => throw failure);
              },
            )),
        throwsA(isA<ViewModelError>()));
    expect(store.isEmpty, isTrue);
    expect(errors, [(failure, ErrorType.dispose)]);
  });

  test('Store disposes remaining handles after a cleanup error sink fails', () {
    failErrorReporting(1);
    final store = Store<_Resource>();
    var secondDisposed = false;
    store.getNotifier(
        factory: InstanceFactory(
      arg: const InstanceArg(key: 'first'),
      builder: () => _Resource(disposed: () => throw StateError('first')),
    ));
    store.getNotifier(
        factory: InstanceFactory(
      arg: const InstanceArg(key: 'second'),
      builder: () => _Resource(disposed: () => secondDisposed = true),
    ));
    expect(store.dispose, returnsNormally);
    expect(secondDisposed, isTrue);
    expect(store.isEmpty, isTrue);
    expect(errors.last.$1.toString(), contains('log sink failed'));
  });

  test('controller can acquire newest instance without a factory', () {
    final owner = _Owner(ViewModelSpec<_Vm>(builder: _Vm.new));
    final guest = ViewModelBinding();
    final controller = AutoDisposeInstanceController(
      onHandleDisposing: () {},
      viewModelBinding: guest,
    );
    addTearDown(owner.dispose);
    addTearDown(guest.dispose);
    addTearDown(controller.dispose);
    owner.vm;
    expect(controller.getInstance<_Vm>(), same(owner.vm));
    expect(owner.vm.refHandler.owners, [owner, guest]);
    controller.dispose();
    expect(() => controller.getInstance<_Vm>(), throwsA(isA<ViewModelError>()));
    expect(owner.vm.refHandler.owners, [owner]);
  });

  test('controller reports a failing recycle notification after detaching', () {
    final owner = _Owner(ViewModelSpec<_Vm>(builder: _Vm.new));
    final guest = ViewModelBinding();
    final failure = StateError('host refresh');
    final controller = AutoDisposeInstanceController(
      onHandleDisposing: () => throw failure,
      viewModelBinding: guest,
    );
    addTearDown(owner.dispose);
    addTearDown(guest.dispose);
    addTearDown(controller.dispose);
    owner.vm;
    controller.getInstance<_Vm>();
    owner.recycle(owner.vm);
    expect(controller.instanceNotifiers, isEmpty);
    expect(errors, [(failure, ErrorType.listener)]);
  });

  test('attachment publishing failure rolls back only its own registration',
      () {
    final owner = _Owner(ViewModelSpec<_Vm>(builder: _Vm.new));
    final guest = ViewModelBinding();
    final failure = StateError('attachment publish');
    final controller = AutoDisposeInstanceController(
      onHandleDisposing: () {},
      viewModelBinding: guest,
      onInstanceAttached: (_, __) => () => throw failure,
    );
    addTearDown(owner.dispose);
    addTearDown(guest.dispose);
    addTearDown(controller.dispose);
    owner.vm;
    expect(() => controller.getInstance<_Vm>(), throwsA(same(failure)));
    expect(owner.vm.refHandler.owners, [owner]);
    expect(controller.instanceNotifiers, isEmpty);
  });

  test('onBind can release an attempted owner while another retains the VM',
      () {
    late _Owner<_Vm> joining;
    final spec = ViewModelSpec<_Vm>(
        builder: () => _Vm(bound: (vm, id) {
              if (id == joining.id) joining.unbind(vm);
            }),
        key: 'shared');
    final keeper = _Owner(spec);
    joining = _Owner(spec);
    addTearDown(keeper.dispose);
    addTearDown(joining.dispose);
    keeper.vm;
    expect(() => joining.vm, throwsA(isA<ViewModelError>()));
    expect(keeper.vm.refHandler.owners, [keeper]);
  });
}
