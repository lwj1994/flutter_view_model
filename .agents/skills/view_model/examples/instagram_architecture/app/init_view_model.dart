import 'package:view_model/view_model.dart';

import '../core/load_phase.dart';
import '../feed/post_feed_view_model.dart';
import '../user/user_view_model.dart';

final initViewModelSpec = ViewModelSpec.arg<InitViewModel, String>(
  builder: (currentUserId) => InitViewModel(currentUserId),
  key: (currentUserId) => 'instagram.init.$currentUserId',
);

class InitState {
  const InitState({
    this.phase = LoadPhase.idle,
    this.error,
  });

  final LoadPhase phase;
  final Object? error;
}

/// Coordinates startup for [currentUserId] without owning User or Feed logic.
class InitViewModel extends StateViewModel<InitState> {
  InitViewModel(this.currentUserId) : super(state: const InitState());

  final String currentUserId;

  UserViewModel get user =>
      viewModelBinding.read(userViewModelSpec(currentUserId));

  PostFeedViewModel get feed =>
      viewModelBinding.read(postFeedViewModelSpec(currentUserId));

  Future<void> initialize() async {
    if (state.phase == LoadPhase.loading || state.phase == LoadPhase.ready) {
      return;
    }

    setState(const InitState(phase: LoadPhase.loading));
    try {
      // Feed requires a restored session, so startup order is explicit.
      await user.load();
      await feed.load();
      setState(const InitState(phase: LoadPhase.ready));
    } catch (error) {
      setState(InitState(phase: LoadPhase.failure, error: error));
    }
  }
}
