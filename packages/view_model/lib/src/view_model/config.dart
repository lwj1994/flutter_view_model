class ViewModelConfig {
  final bool logEnable;

  /// custom isSameState function for [StateViewModel]
  /// if return true, the viewModel will not be updated
  final bool Function(dynamic previous, dynamic state)? isSameState;

  ViewModelConfig({
    this.logEnable = false,
    this.isSameState,
  });
}
