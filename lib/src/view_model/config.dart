class ViewModelConfig {
  final bool logEnable;

  final bool Function(dynamic previous, dynamic state)? isSameState;

  ViewModelConfig({
    this.logEnable = false,
    this.isSameState,
  });
}
