import 'package:view_model/view_model.dart';

import '../core/load_phase.dart';
import '../models/user.dart';
import 'user_repo.dart';

final userViewModelSpec = ViewModelSpec.arg<UserViewModel, String>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'instagram.user.$userId',
);

class UserState {
  const UserState({
    this.phase = LoadPhase.idle,
    this.user,
    this.error,
  });

  final LoadPhase phase;
  final User? user;
  final Object? error;
}

/// Loads and exposes one user identified by [userId].
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel(this.userId) : super(state: const UserState());

  final String userId;

  // Use read: repository notifications do not need to refresh UserViewModel.
  UserRepo get repo => viewModelBinding.read(userRepoSpec);

  Future<void> load() async {
    if (state.phase == LoadPhase.loading || state.phase == LoadPhase.ready) {
      return;
    }

    setState(const UserState(phase: LoadPhase.loading));
    try {
      final user = await repo.getUser(userId);
      setState(UserState(phase: LoadPhase.ready, user: user));
    } catch (error) {
      setState(UserState(phase: LoadPhase.failure, error: error));
      rethrow;
    }
  }
}
