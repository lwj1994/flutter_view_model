/// ViewModelVisibleListener controls manual pause/resume for a page/state.
///
/// - Call [onPause] to mark the page as paused (e.g., covered by another route).
///   While paused, rebuilds triggered by bound ViewModels are ignored.
/// - Call [onResume] to mark as resumed and invoke the provided callback to
///   trigger a single refresh.
class ViewModelVisibleListener {
  /// Callback invoked when [onResume] is called to force a refresh.
  final Function() resumeCallBack;

  /// Whether the page/state is currently resumed (not paused).
  bool _isResumed = true;

  /// Creates a [ViewModelVisibleListener] with the callback used to trigger refresh
  /// when resuming.
  ViewModelVisibleListener(this.resumeCallBack);

  /// Whether the page/state is currently resumed (not paused).
  bool get isResumed => _isResumed;

  /// Marks the page/state as resumed and triggers the refresh callback.
  void onResume() {
    _isResumed = true;
    resumeCallBack();
  }

  /// Marks the page/state as paused (covered).
  void onPause() {
    _isResumed = false;
  }
}
