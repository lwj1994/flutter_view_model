import 'package:view_model/view_model.dart';

import '../core/instagram_api.dart';
import '../models/post.dart';

final postRepoSpec = ViewModelSpec<PostRepo>(
  builder: PostRepo.new,
  key: 'instagram.post-repo',
);

class PostRepo with ViewModel {
  InstagramApi get api => viewModelBinding.read(instagramApiSpec);

  Future<List<Post>> getFeed(String userId) => api.fetchFeed(userId);

  Future<Post> getPost(String postId) => api.fetchPost(postId);
}
