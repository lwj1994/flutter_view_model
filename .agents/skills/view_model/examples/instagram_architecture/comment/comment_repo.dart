import 'package:view_model/view_model.dart';

import '../core/instagram_api.dart';
import '../models/comment.dart';
import '../models/user.dart';

final commentRepoSpec = ViewModelSpec<CommentRepo>(
  builder: CommentRepo.new,
  key: 'instagram.comment-repo',
);

class CommentRepo with ViewModel {
  InstagramApi get api => viewModelBinding.read(instagramApiSpec);

  Future<List<Comment>> getComments(String postId) => api.fetchComments(postId);

  Future<Comment> addComment({
    required String postId,
    required User author,
    required String message,
  }) =>
      api.createComment(
        postId: postId,
        author: author,
        message: message,
      );
}
