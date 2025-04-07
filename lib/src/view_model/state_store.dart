// @author luwenjie on 2025/3/26 17:32:40

import 'dart:async';

class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<DiffState<S>> _stateStreamController =
      StreamController.broadcast(
    onCancel: () {},
    onListen: () {},
  );

  final S initialState;

  ViewModelStateStore({
    required this.initialState,
  });

  late S _state = initialState;
  S? _previousState;

  @override
  S get state => _state;

  @override
  S? get previousState => _previousState;

  void dispose() {
    _stateStreamController.close();
  }

  @override
  Stream<DiffState<S>> get stateStream => _stateStreamController.stream;

  /// set state directly blockly
  void _update(S state) {
    if (state == _state) return;
    _previousState = _state;
    _state = state;
    _stateStreamController.add(DiffState(_previousState, _state));
  }

  @override
  void setState(S state) {
    _update(state);
  }
}

abstract class StateStore<S> {
  abstract final S state;
  abstract final S? previousState;
  abstract final Stream<DiffState<S>> stateStream;

  void setState(S state);
}

class Reducer<S> {
  final FutureOr<S> Function(S state) builder;

  Reducer({
    required this.builder,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reducer &&
          runtimeType == other.runtimeType &&
          builder == other.builder;

  @override
  int get hashCode => builder.hashCode;
}

class ViewModelError extends StateError {
  ViewModelError(super.message);
}

class DiffState<T> {
  final T? p;
  final T n;

  const DiffState(this.p, this.n);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffState &&
          runtimeType == other.runtimeType &&
          p == other.p &&
          n == other.n;

  @override
  int get hashCode => p.hashCode ^ n.hashCode;
}
