import 'package:view_model/view_model.dart';

import '../core/load_phase.dart';
import '../models/comment.dart';
import '../user/user_view_model.dart';
import 'comment_repo.dart';

final commentViewModelSpec =
    ViewModelSpec.arg2<CommentViewModel, String, String>(
  builder: (postId, currentUserId) => CommentViewModel(postId, currentUserId),
  key: (postId, currentUserId) => 'instagram.comments.$currentUserId.$postId',
);

class CommentState {
  const CommentState({
    this.phase = LoadPhase.idle,
    this.comments = const [],
    this.isSubmitting = false,
    this.error,
  });

  final LoadPhase phase;
  final List<Comment> comments;
  final bool isSubmitting;
  final Object? error;
}

/// Owns comments for one [postId] and writes as [currentUserId].
class CommentViewModel extends StateViewModel<CommentState> {
  CommentViewModel(this.postId, this.currentUserId)
      : super(state: const CommentState());

  final String postId;
  final String currentUserId;

  CommentRepo get repo => viewModelBinding.read(commentRepoSpec);

  // Resolves the same keyed UserViewModel used by the startup flow.
  UserViewModel get currentUser =>
      viewModelBinding.read(userViewModelSpec(currentUserId));

  Future<void> load() async {
    if (state.phase == LoadPhase.loading || state.phase == LoadPhase.ready) {
      return;
    }

    setState(CommentState(
      phase: LoadPhase.loading,
      comments: state.comments,
    ));
    try {
      final comments = await repo.getComments(postId);
      setState(CommentState(
        phase: LoadPhase.ready,
        comments: comments,
      ));
    } catch (error) {
      setState(CommentState(
        phase: LoadPhase.failure,
        comments: state.comments,
        error: error,
      ));
      rethrow;
    }
  }

  Future<void> add(String rawMessage) async {
    final message = rawMessage.trim();
    if (message.isEmpty || state.isSubmitting) return;

    final author = currentUser.state.user;
    if (author == null) {
      throw StateError('InitViewModel must initialize UserViewModel first');
    }

    setState(CommentState(
      phase: state.phase,
      comments: state.comments,
      isSubmitting: true,
    ));
    try {
      final comment = await repo.addComment(
        postId: postId,
        author: author,
        message: message,
      );
      setState(CommentState(
        phase: LoadPhase.ready,
        comments: [...state.comments, comment],
      ));
    } catch (error) {
      setState(CommentState(
        phase: state.phase,
        comments: state.comments,
        error: error,
      ));
      rethrow;
    }
  }
}
