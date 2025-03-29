// @author luwenjie on 2025/3/26 17:32:40

import 'dart:async';
import 'dart:collection';

import 'package:view_model/src/log.dart';
import 'package:view_model/src/view_model/extension.dart';

class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<FutureOr<S> Function(S)> _setStateController =
      StreamController<FutureOr<S> Function(S)>();
  final StreamController<S> _stateStreamController = StreamController.broadcast(
    onCancel: () {},
    onListen: () {},
  );

  final StreamController<AsyncState<S>> _asyncStateStreamController =
      StreamController.broadcast(
    onCancel: () {},
    onListen: () {},
  );

  final S initialState;

  late StreamSubscription<FutureOr<S> Function(S)>? _subscription;
  final Queue<FutureOr<S> Function(S)> _reducerQueue = Queue();
  bool _isProcessing = false;

  ViewModelStateStore({
    required this.initialState,
  }) {
    _subscribe();
  }

  Future<void> _subscribe() async {
    _subscription = _setStateController.stream.listen(
      (FutureOr<S> Function(S) reducer) async {
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

    _asyncState = AsyncLoading(state: state);
    _asyncStateStreamController.add(_asyncState);
    _isProcessing = true;
    final reducer = _reducerQueue.removeFirst();
    try {
      final newState = await reducer(_state);
      if (newState == _state) {
        viewModelLog("${S} ignore same state $_state");
        //
        _asyncState = AsyncSuccess(
          state: state,
          changed: false,
        );
        _asyncStateStreamController.add(_asyncState);
      } else {
        _previousState = _state;
        _state = newState;
        _stateStreamController.add(newState);
        _asyncState = AsyncSuccess(
          state: newState,
          changed: true,
        );
        _asyncStateStreamController.add(_asyncState);
      }
    } catch (e) {
      viewModelLog("${S} reducer $e");
      _asyncStateStreamController.add(AsyncError(error: e));
    }

    await _processNextReducer();
  }

  @override
  void set(FutureOr<S> Function(S state) reducer) {
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
    _stateStreamController.close();
    _asyncStateStreamController.close();
    _setStateController.close();
    _subscription?.cancel();
    _reducerQueue.clear();
  }

  @override
  Stream<S> get stateStream => _stateStreamController.stream;

  @override
  Stream<AsyncState<S>> get asyncStateStream =>
      _asyncStateStreamController.stream;

  @override
  AsyncState<S> get asyncState => _asyncState;
}

abstract class StateStore<S> {
  abstract final S state;
  abstract final AsyncState<S> asyncState;
  abstract final S? previousState;
  abstract final Stream<S> stateStream;
  abstract final Stream<AsyncState<S>> asyncStateStream;

  void set(FutureOr<S> Function(S state) reducer);
}
