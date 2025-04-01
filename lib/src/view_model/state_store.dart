// @author luwenjie on 2025/3/26 17:32:40

import 'dart:async';
import 'dart:collection';

import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/extension.dart';

class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<Reducer<S>> _setStateController =
      StreamController<Reducer<S>>();

  final StreamController<AsyncState<S>> _asyncStateStreamController =
      StreamController.broadcast(
    onCancel: () {},
    onListen: () {},
  );

  final S initialState;

  late StreamSubscription<Reducer<S>>? _subscription;
  final Queue<Reducer<S>> _reducerQueue = Queue();
  bool _isProcessing = false;

  ViewModelStateStore({
    required this.initialState,
  }) {
    _subscribe();
  }

  Future<void> _subscribe() async {
    _subscription = _setStateController.stream.listen(
      (Reducer<S> reducer) async {
        _reducerQueue.add(reducer);
        if (!_isProcessing) {
          await _processNextReducer();
        }
      },
    );
  }

  FutureOr<void> _processNextReducer() async {
    if (_reducerQueue.isEmpty) {
      _isProcessing = false;
      return;
    }
    _isProcessing = true;
    final reducer = _reducerQueue.removeFirst();
    _asyncState = AsyncLoading(
      state: state,
      tag: reducer.tag,
    );
    _asyncStateStreamController.add(_asyncState);
    try {
      final newState = await reducer.builder(_state);
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
    } catch (e) {
      viewModelLog("$S reducer $e");
      _asyncStateStreamController.add(AsyncError(
        error: e,
        tag: reducer.tag,
      ));
    }

    await _processNextReducer();
  }

  @override
  void set(Reducer<S> reducer) {
    _setStateController.add(reducer);
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
    _setStateController.close();
    _subscription?.cancel();
    _reducerQueue.clear();
  }

  @override
  Stream<AsyncState<S>> get asyncStateStream =>
      _asyncStateStreamController.stream;

  @override
  AsyncState<S> get asyncState => _asyncState;

  @override
  Queue<Reducer<S>> get pendingReducers => _reducerQueue;
}

abstract class StateStore<S> {
  abstract final S state;
  abstract final AsyncState<S> asyncState;
  abstract final S? previousState;
  abstract final Queue<Reducer<S>> pendingReducers;
  abstract final Stream<AsyncState<S>> asyncStateStream;

  void set(Reducer<S> reducer);
}

class Reducer<S> {
  final FutureOr<S> Function(S state) builder;
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
