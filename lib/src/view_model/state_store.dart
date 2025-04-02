// @author luwenjie on 2025/3/26 17:32:40

import 'dart:async';

class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<S> _stateStreamController = StreamController.broadcast(
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
  Stream<S> get stateStream => _stateStreamController.stream;

  /// set state directly blockly
  void _update(S state) {
    if (state == _state) return;
    _previousState = _state;
    _state = state;
    _stateStreamController.add(_state);
  }

  @override
  Future<S> setState(Reducer<S> reducer) async {
    final newState = await reducer.builder.call(state);
    _update(newState);
    return newState;
  }
}

abstract class StateStore<S> {
  abstract final S state;
  abstract final S? previousState;
  abstract final Stream<S> stateStream;

  FutureOr<S> setState(Reducer<S> reducer);
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
