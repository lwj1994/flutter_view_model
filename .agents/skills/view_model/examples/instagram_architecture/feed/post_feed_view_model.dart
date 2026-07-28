import 'package:view_model/view_model.dart';

import '../core/load_phase.dart';
import '../models/post.dart';
import '../post/post_repo.dart';

final postFeedViewModelSpec = ViewModelSpec.arg<PostFeedViewModel, String>(
  builder: (userId) => PostFeedViewModel(userId),
  key: (userId) => 'instagram.post-feed.$userId',
);

class PostFeedState {
  const PostFeedState({
    this.phase = LoadPhase.idle,
    this.posts = const [],
    this.error,
  });

  final LoadPhase phase;
  final List<Post> posts;
  final Object? error;
}

/// Owns the personalized post feed for one [userId].
class PostFeedViewModel extends StateViewModel<PostFeedState> {
  PostFeedViewModel(this.userId) : super(state: const PostFeedState());

  final String userId;

  PostRepo get repo => viewModelBinding.read(postRepoSpec);

  Future<void> load({bool force = false}) async {
    if (state.phase == LoadPhase.loading ||
        (!force && state.phase == LoadPhase.ready)) {
      return;
    }

    setState(PostFeedState(
      phase: LoadPhase.loading,
      posts: state.posts,
    ));
    try {
      final posts = await repo.getFeed(userId);
      setState(PostFeedState(phase: LoadPhase.ready, posts: posts));
    } catch (error) {
      setState(PostFeedState(
        phase: LoadPhase.failure,
        posts: state.posts,
        error: error,
      ));
      rethrow;
    }
  }
}
