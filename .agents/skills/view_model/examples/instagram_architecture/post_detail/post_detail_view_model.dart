import 'package:view_model/view_model.dart';

import '../comment/comment_view_model.dart';
import '../core/load_phase.dart';
import '../models/post.dart';
import '../post/post_repo.dart';

final postDetailViewModelSpec =
    ViewModelSpec.arg2<PostDetailViewModel, String, String>(
  builder: (postId, currentUserId) =>
      PostDetailViewModel(postId, currentUserId),
  key: (postId, currentUserId) =>
      'instagram.post-detail.$currentUserId.$postId',
);

class PostDetailState {
  const PostDetailState({
    this.phase = LoadPhase.idle,
    this.post,
    this.error,
  });

  final LoadPhase phase;
  final Post? post;
  final Object? error;
}

/// Owns one [postId] detail subtree for [currentUserId].
class PostDetailViewModel extends StateViewModel<PostDetailState> {
  PostDetailViewModel(this.postId, this.currentUserId)
      : super(state: const PostDetailState());

  final String postId;
  final String currentUserId;

  PostRepo get repo => viewModelBinding.read(postRepoSpec);

  // Use watch so comment updates propagate through this module to the page.
  CommentViewModel get comments => viewModelBinding.watch(
        commentViewModelSpec(postId, currentUserId),
      );

  Future<void> load() async {
    if (state.phase == LoadPhase.loading || state.phase == LoadPhase.ready) {
      return;
    }

    setState(const PostDetailState(phase: LoadPhase.loading));
    try {
      // Load both modules concurrently. Resolving the getter also establishes
      // the parent-to-child lifecycle edge.
      final postFuture = repo.getPost(postId);
      final commentsFuture = comments.load();
      final post = await postFuture;
      await commentsFuture;
      setState(PostDetailState(phase: LoadPhase.ready, post: post));
    } catch (error) {
      setState(PostDetailState(phase: LoadPhase.failure, error: error));
    }
  }

  Future<void> addComment(String message) => comments.add(message);
}
