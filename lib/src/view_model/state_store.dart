// @author luwenjie on 2025/3/26 17:32:40

import 'dart:async';
import 'dart:collection';

import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/extension.dart';

class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<AsyncState<S>> _asyncStateStreamController =
      StreamController.broadcast(
    onCancel: () {},
    onListen: () {},
  );

  final S initialState;

  final Queue<Reducer<S>> _reducerQueue = Queue();
  Reducer<S>? _executingReducer;

  ViewModelStateStore({
    required this.initialState,
  });

  FutureOr<void> _tryTriggerNextReducer() async {
    if (_reducerQueue.isEmpty || _executingReducer != null) {
      return;
    }
    await _handle(_reducerQueue.removeFirst());
    await _tryTriggerNextReducer();
  }

  Future<void> _handle(Reducer<S> reducer) async {
    _executingReducer = reducer;
    _asyncState = AsyncLoading(
      state: state,
      tag: reducer.tag,
    );
    _asyncStateStreamController.add(_asyncState);
    try {
      final newState = await reducer.builder(_state);
      switch (newState) {
        case AsyncLoading<S>():
          throw ViewModelError("reducer only set AsyncSuccess or AsyncError");
        case AsyncSuccess<S>():
          _onSuccess(newState.state as S, reducer);
          break;
        case AsyncError<S>():
          _onError(newState.error, reducer);
          break;
      }
    } catch (e) {
      if (e is ViewModelError) {
        rethrow;
      }
      _onError(e, reducer);
    } finally {
      _executingReducer = null;
    }
  }

  void _onSuccess(S newState, Reducer<S> reducer) {
    if (newState == _state) {
      viewModelLog("$S ignore same state $_state");
      //
      _asyncState = AsyncSuccess(
        state: state,
        changed: false,
        tag: reducer.tag,
      );
      _asyncStateStreamController.add(_asyncState);
    } else {
      _previousState = _state;
      _state = newState;
      _asyncState = AsyncSuccess(
        state: newState,
        changed: true,
        tag: reducer.tag,
      );
      _asyncStateStreamController.add(_asyncState);
    }
  }

  void _onError(dynamic e, Reducer<S> reducer) {
    viewModelLog("$S reducer $e");
    _asyncState = AsyncError(tag: reducer.tag, error: e);
    _asyncStateStreamController.add(_asyncState);
  }

  @override
  void setReducer(Reducer<S> reducer) {
    _reducerQueue.add(reducer);
    _tryTriggerNextReducer();
  }

  late S _state = initialState;
  late AsyncState<S> _asyncState = AsyncSuccess(state: state);
  S? _previousState;

  @override
  S get state => _state;

  @override
  S? get previousState => _previousState;

  void dispose() {
    _asyncStateStreamController.close();
    _reducerQueue.clear();
    _executingReducer = null;
  }

  @override
  Stream<AsyncState<S>> get asyncStateStream =>
      _asyncStateStreamController.stream;

  @override
  AsyncState<S> get asyncState => _asyncState;

  @override
  Queue<Reducer<S>> get pendingReducers => _reducerQueue;

  @override
  Reducer<S>? get executingReducer => _executingReducer;

  /// set state directly blockly
  void setState(S state) {
    if (state == _state) return;
    _previousState = _state;
    _state = state;
    _asyncState = AsyncSuccess(state: state);
    _asyncStateStreamController.add(_asyncState);
  }
}

abstract class StateStore<S> {
  abstract final S state;
  abstract final AsyncState<S> asyncState;
  abstract final S? previousState;
  abstract final Queue<Reducer<S>> pendingReducers;
  abstract final Reducer<S>? executingReducer;
  abstract final Stream<AsyncState<S>> asyncStateStream;

  void setReducer(Reducer<S> reducer);
}

class Reducer<S> {
  final FutureOr<AsyncState<S>> Function(S state) builder;
  final Object? tag;

  Reducer({
    required this.builder,
    this.tag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reducer &&
          runtimeType == other.runtimeType &&
          builder == other.builder &&
          tag == other.tag;

  @override
  int get hashCode => builder.hashCode ^ tag.hashCode;
}

class ViewModelError extends StateError {
  ViewModelError(super.message);
}
