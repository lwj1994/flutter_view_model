// @author luwenjie on 2025/3/26 17:32:40

import 'dart:async';
import 'dart:collection';

class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<FutureOr<S> Function(S)> _setStateController =
      StreamController<FutureOr<S> Function(S)>();
  final StreamController<S> _stateStreamController = StreamController.broadcast(
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
    _isProcessing = true;
    final reducer = _reducerQueue.removeFirst();
    final newState = await reducer(_state);
    if (newState == _state) {
      //
    } else {
      _previousState = _state;
      _state = newState;
      _stateStreamController.add(newState);
    }
    await _processNextReducer();
  }

  @override
  void set(FutureOr<S> Function(S state) reducer) {
    _setStateController.add(reducer);
  }

  late S _state = initialState;
  S? _previousState;

  @override
  S get state => _state;

  @override
  S? get previousState => _previousState;

  void dispose() {
    _stateStreamController.close();
    _setStateController.close();
    _subscription?.cancel();
    _reducerQueue.clear();
  }

  @override
  Stream<S> get stateStream => _stateStreamController.stream;
}

abstract class StateStore<S> {
  abstract final S state;
  abstract final S? previousState;
  abstract final Stream<S> stateStream;

  void set(FutureOr<S> Function(S state) reducer);
}
