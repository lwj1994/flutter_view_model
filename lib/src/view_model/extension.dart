// @author luwenjie on 2025/3/25 17:24:31

import 'package:flutter/cupertino.dart';
import 'package:uuid/v4.dart';
import 'package:view_model/src/get_instance/auto_dispose.dart';
import 'package:view_model/src/get_instance/manager.dart';
import 'package:view_model/src/view_model/view_model.dart';

mixin ViewModelStateMixin<T extends StatefulWidget> on State<T> {
  late final _instanceController =
      AutoDisposeInstanceController(onRecreate: () {
    setState(() {});
  });
  final Map<ViewModel, bool> _stateListeners = {};

  final _defaultViewModelKey = const UuidV4().generate();
  final List<Function()> _disposes = [];
  bool _dispose = false;

  @override
  @mustCallSuper
  void initState() {
    super.initState();
  }

  void refreshViewModel<VM extends ViewModel>(VM vm) {
    instanceManager.recreate(vm);
    setState(() {});
  }

  void listenViewModelState<VM extends ViewModel<S>, S>(VM vm,
      {required Function(S? p, S n) onChange}) {
    _disposes.add(vm.listen((s) {
      onChange(vm.previousState, s);
    }));
  }

  void listenViewModelAsyncState<VM extends ViewModel<S>, S>(
    VM vm, {
    required Function(AsyncState<S>) onChange,
  }) {
    _disposes.add(vm.listenAsync(onChange));
  }

  /// [ViewModel] trigger rebuilding automatically.
  VM getViewModel<VM extends ViewModel>({
    required ViewModelFactory<VM> factory,
  }) {
    if (_dispose) {
      throw StateError("state is disposed");
    }
    String key = factory.key() ?? _defaultViewModelKey;
    final res = _instanceController.getInstance<VM>(
      factory: InstanceFactory<VM>(
        key: key,
        builder: () => factory.build(),
      ),
    );
    if (_stateListeners[res] != true) {
      res.listenAsync((as) async {
        if (_dispose) return;
        while (!context.mounted) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (_dispose) return;
        }
        switch (as) {
          case AsyncLoading():
            setState(() {});
            break;
          case AsyncSuccess():
            if (as.changed) {
              setState(() {});
            }
            setState(() {});
            break;
          case AsyncError():
            setState(() {});
            break;
        }
      });
    }
    return res;
  }

  @override
  @mustCallSuper
  void dispose() {
    _dispose = true;
    _stateListeners.clear();
    _instanceController.dispose();
    for (var e in _disposes) {
      e.call();
    }
    super.dispose();
  }
}

sealed class AsyncState<T> {
  final Object? tag;
  final T? state;

  AsyncState({
    this.state,
    this.tag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncState &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          state == other.state;

  @override
  int get hashCode => tag.hashCode ^ state.hashCode;
}

class AsyncLoading<T> extends AsyncState<T> {
  AsyncLoading({super.state, super.tag});

  @override
  String toString() {
    return "AsyncLoading(tag: $tag, state: $state)";
  }
}

class AsyncSuccess<T> extends AsyncState<T> {
  final bool changed;

  AsyncSuccess({required T state, this.changed = true, super.tag})
      : super(state: state);

  @override
  String toString() {
    return "AsyncSuccess(tag: $tag, state: $state)";
  }
}

class AsyncError<T> extends AsyncState<T> {
  final dynamic error;

  AsyncError({this.error, super.tag});

  @override
  String toString() {
    return "AsyncError(tag: $tag, error: $error)";
  }
}
