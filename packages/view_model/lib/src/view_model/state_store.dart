// @author luwenjie on 2025/3/26 17:32:40

/// State management store for ViewModels.
///
/// This file contains the core state management classes used by StateViewModels:
/// - [ViewModelStateStore]: Concrete implementation of state storage
/// - [StateStore]: Abstract interface for state management
/// - [DiffState]: Container for state changes with previous/current values
/// - [Reducer]: Function wrapper for state transformations
/// - [ViewModelError]: Custom error type for ViewModel-related errors
///
/// The state store handles state updates, change notifications, and provides
/// a stream of state changes for reactive programming.
library;

import 'dart:async';

import 'package:view_model/src/view_model/view_model.dart';

/// Concrete implementation of state storage for ViewModels.
///
/// This class manages state for [StateViewModel] instances, providing:
/// - State storage and retrieval
/// - Change detection and notifications
/// - Stream-based state updates
/// - Previous state tracking
///
/// The store uses a broadcast stream to notify multiple listeners of state changes
/// and implements configurable state equality checking.
///
/// Example:
/// ```dart
/// final store = ViewModelStateStore<int>(initialState: 0);
/// store.stateStream.listen((diff) {
///   print('State changed from ${diff.p} to ${diff.n}');
/// });
/// store.setState(1); // Triggers notification
/// ```
class ViewModelStateStore<S> implements StateStore<S> {
  final StreamController<DiffState<S>> _stateStreamController =
      StreamController.broadcast(
    onCancel: () {},
    onListen: () {},
  );

  /// The initial state provided when the store was created.
  final S initialState;

  /// Creates a new state store with the given initial state.
  ///
  /// Parameters:
  /// - [initialState]: The initial state value
  ViewModelStateStore({
    required this.initialState,
  });

  late S _state = initialState;
  S? _previousState;

  /// Gets the current state.
  @override
  S get state => _state;

  /// Gets the previous state before the last update.
  ///
  /// Returns `null` if no previous state exists (i.e., no updates have been made).
  @override
  S? get previousState => _previousState;

  /// Disposes the state store and closes the state stream.
  ///
  /// This method should be called when the store is no longer needed
  /// to prevent memory leaks.
  void dispose() {
    _stateStreamController.close();
  }

  /// Gets the stream of state changes.
  ///
  /// Each emission contains both the previous and current state,
  /// allowing listeners to react to specific changes.
  @override
  Stream<DiffState<S>> get stateStream => _stateStreamController.stream;

  /// Updates the state directly and synchronously.
  ///
  /// This internal method performs the actual state update, including:
  /// - State equality checking to avoid unnecessary updates
  /// - Previous state tracking
  /// - Listener notification
  ///
  /// Parameters:
  /// - [state]: The new state to set
  void _update(S state) {
    if (_isSameState(_state, state)) return;
    _previousState = _state;
    _state = state;
    notifyListeners();
  }

  /// Checks if two states are considered equal.
  ///
  /// Uses the configured state equality function from [ViewModel.config]
  /// if available, otherwise falls back to identity comparison.
  ///
  /// Parameters:
  /// - [current]: Current state
  /// - [newState]: New state to compare against
  ///
  /// Returns `true` if the states are considered equal.
  bool _isSameState(S current, S newState) {
    if (ViewModel.config.equals != null) {
      return ViewModel.config.equals!(current, newState);
    } else {
      return identical(current, newState);
    }
  }

  /// Notifies all listeners of state changes without changing the state.
  ///
  /// This method can be used to trigger a refresh when the state object
  /// itself hasn't changed but its internal properties might have.
  void notifyListeners() {
    _stateStreamController.add(DiffState(_previousState, _state));
  }

  /// Sets a new state and notifies listeners.
  ///
  /// This is the main method for updating state. It will only trigger
  /// notifications if the new state is different from the current state
  /// according to the configured equality function.
  ///
  /// Parameters:
  /// - [state]: The new state to set
  @override
  void setState(S state) {
    _update(state);
  }
}

/// Abstract interface for state storage.
///
/// This interface defines the contract for state management in ViewModels.
/// Implementations should provide state storage, change tracking, and
/// notification capabilities.
///
/// Type parameter [S] represents the type of state being managed.
abstract class StateStore<S> {
  /// The current state.
  abstract final S state;

  /// The previous state before the last update, or null if no updates have occurred.
  abstract final S? previousState;

  /// A stream of state changes containing both previous and current state.
  abstract final Stream<DiffState<S>> stateStream;

  /// Updates the state and notifies listeners.
  ///
  /// Parameters:
  /// - [state]: The new state to set
  void setState(S state);
}

/// A function wrapper for state transformations.
///
/// Reducers encapsulate state transformation logic and can be used
/// to create reusable state update patterns. They support both
/// synchronous and asynchronous transformations.
///
/// Example:
/// ```dart
/// final incrementReducer = Reducer<int>(
///   builder: (state) => state + 1,
/// );
///
/// final asyncReducer = Reducer<String>(
///   builder: (state) async {
///     final result = await fetchData();
///     return '$state-$result';
///   },
/// );
/// ```
class Reducer<S> {
  /// The transformation function that takes current state and returns new state.
  ///
  /// Can be either synchronous or asynchronous (returning a Future).
  final FutureOr<S> Function(S state) builder;

  /// Creates a new reducer with the given transformation function.
  ///
  /// Parameters:
  /// - [builder]: The state transformation function
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

/// Represents an error that occurred within a ViewModel.
///
/// This class encapsulates error information including a descriptive message,
/// the original error object, and stack trace for debugging purposes.
///
/// Example:
/// ```dart
/// try {
///   await someAsyncOperation();
/// } catch (error, stackTrace) {
///   final viewModelError = ViewModelError(
///     message: 'Failed to load data',
///     error: error,
///     stackTrace: stackTrace,
///   );
///   // Handle or propagate the error
/// }
/// ```
class ViewModelError {
  /// A human-readable description of the error.
  final String message;

  /// The original error object that caused this ViewModel error.
  final Object? error;

  /// The stack trace at the point where the error occurred.
  final StackTrace? stackTrace;

  /// Creates a new ViewModel error.
  ///
  /// Parameters:
  /// - [message]: A descriptive error message
  /// - [error]: The original error object (optional)
  /// - [stackTrace]: The stack trace where the error occurred (optional)
  ViewModelError({
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'ViewModelError{message: $message, error: $error, stackTrace: $stackTrace}';
  }
}

/// Represents a state change containing both previous and current state.
///
/// This class is used to communicate state transitions through the state stream,
/// allowing listeners to react to specific changes by comparing previous and
/// current values.
///
/// Example:
/// ```dart
/// stateStream.listen((diffState) {
///   print('State changed from ${diffState.previousState} to
///   ${diffState.currentState}');
///
///   // React to specific changes
///   if (diffState.previousState?.isLoading == true &&
///       diffState.currentState.isLoading == false) {
///     print('Loading completed');
///   }
/// });
/// ```
class DiffState<S> {
  /// The state before the change, or null if this is the initial state.
  final S? previousState;

  /// The current state after the change.
  final S currentState;

  /// Creates a new state difference.
  ///
  /// Parameters:
  /// - [previousState]: The state before the change (null for initial state)
  /// - [currentState]: The current state after the change
  DiffState(this.previousState, this.currentState);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffState &&
          runtimeType == other.runtimeType &&
          previousState == other.previousState &&
          currentState == other.currentState;

  @override
  int get hashCode => previousState.hashCode ^ currentState.hashCode;

  @override
  String toString() {
    return 'DiffState{previousState: $previousState, currentState: $currentState}';
  }
}
