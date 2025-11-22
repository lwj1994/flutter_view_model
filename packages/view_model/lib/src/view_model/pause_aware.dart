import 'dart:async';

import 'package:view_model/src/view_model/pause_provider.dart';

/// A controller that manages pause/resume lifecycle for a ViewModel, based on a
/// collection of [ViewModelPauseProvider]s.
///
/// This class is designed to be flexible and can work with any source of
/// lifecycle events, such as route navigation or application state changes. For
/// Flutter's default behavior, use the provided default providers. For custom
/// or mixed-stack environments, implement your own [ViewModelPauseProvider] and
/// pass them to the constructor.
class PauseAwareController {
  // A callback triggered when the view model should pause.
  final Function() onWidgetPause;

  // A callback triggered when the view model should resume.
  final Function() onWidgetResume;

  final String Function() binderName;

  /// Creates a [PauseAwareController] with the given pause/resume callbacks.
  ///
  /// If no [providers] are provided, it defaults to using Flutter's standard
  /// [PageRoutePauseProvider] and [AppPauseProvider].
  ///
  /// For custom lifecycle sources (e.g., mixed-stack environments), provide a
  /// list of your custom [ViewModelPauseProvider] implementations.
  PauseAwareController({
    required this.onWidgetPause,
    required this.onWidgetResume,
    required List<ViewModelPauseProvider> providers,
    required this.binderName,
    List<ViewModelPauseProvider>? disposableProviders,
  }) : _disposableProviders = disposableProviders ?? [] {
    _providers.addAll(providers);
    _setupSubscriptions();
  }

  // A list of providers that determine the pause state.
  final List<ViewModelPauseProvider> _providers = [];

  List<ViewModelPauseProvider> get providers => List.unmodifiable(_providers);

  // Providers that should be disposed when this controller is disposed.
  final List<ViewModelPauseProvider> _disposableProviders;

  // Holds subscriptions to the pause state streams of the providers.
  final Map<ViewModelPauseProvider, StreamSubscription<bool>> _subscriptions =
      {};

  // Combines all provider states to determine the final pause state.
  // Returns true if the view model is currently paused.
  bool get isPaused => _isPausedByProviders;

  // The current combined pause state from all providers.
  bool _isPausedByProviders = false;

  // Subscribes to all providers to listen for pause state changes.
  void _setupSubscriptions() {
    for (final provider in _providers) {
      _subscribeToProvider(provider);
    }
  }

  void _subscribeToProvider(ViewModelPauseProvider provider) {
    if (_subscriptions.containsKey(provider)) return;
    // ignore: cancel_subscriptions
    final subscription = provider.onPauseStateChanged.listen((shouldPause) {
      _handleProviderStateChange(provider, shouldPause);
    });
    _subscriptions[provider] = subscription;
  }

  void addProvider(ViewModelPauseProvider provider) {
    if (_providers.contains(provider)) return;
    _providers.add(provider);
    _subscribeToProvider(provider);
  }

  void removeProvider(ViewModelPauseProvider provider) {
    if (_providers.remove(provider)) {
      final subscription = _subscriptions.remove(provider);
      subscription?.cancel();
      _providerPauseStates.remove(provider);
      _reevaluatePauseState();
    }
  }

  // Handles a pause state change signaled by a single provider.
  void _handleProviderStateChange(
      ViewModelPauseProvider provider, bool shouldPause) {
    _providerPauseStates[provider] = shouldPause;
    _reevaluatePauseState();
  }

  // A simple map to track the pause state signaled by each provider
  // Tracks the individual pause state of each provider.
  final Map<ViewModelPauseProvider, bool> _providerPauseStates = {};

  // Re-evaluates the combined pause state from all providers.
  void _reevaluatePauseState() {
    final newPauseState =
        _providerPauseStates.values.any((isPaused) => isPaused);
    if (_isPausedByProviders != newPauseState) {
      _isPausedByProviders = newPauseState;
      _updatePauseState();
    }
  }

  // Updates the view model's pause/resume state and triggers callbacks.
  void _updatePauseState() {
    if (_isPausedByProviders) {
      onWidgetPause();
    } else {
      onWidgetResume();
    }
  }

  /// Disposes the controller and all its subscriptions.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    for (final provider in _disposableProviders) {
      provider.dispose();
    }
    _providerPauseStates.clear();
  }
}
