import 'package:view_model/view_model.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../models/user.dart';

final instagramApiSpec = ViewModelSpec<InstagramApi>(
  builder: InstagramApi.new,
  key: 'instagram.api',
);

/// Simulates a remote API with in-memory data so the example runs offline.
class InstagramApi with ViewModel {
  static const _currentUser = User(
    id: 'user-milu',
    username: 'milu',
    displayName: 'Milu',
  );

  static const _ada = User(
    id: 'user-ada',
    username: 'ada',
    displayName: 'Ada Lovelace',
  );

  static const _linus = User(
    id: 'user-linus',
    username: 'linus',
    displayName: 'Linus Torvalds',
  );

  static const _users = [_currentUser, _ada, _linus];

  final List<Post> _posts = const [
    Post(
      id: 'post-1',
      author: _ada,
      caption: 'Break complex systems into modules with clear boundaries.',
      likeCount: 1842,
    ),
    Post(
      id: 'post-2',
      author: _linus,
      caption: 'Good architecture makes lifecycle relationships visible.',
      likeCount: 936,
    ),
  ];

  final Map<String, List<Comment>> _comments = {
    'post-1': [
      const Comment(
        id: 'comment-1',
        postId: 'post-1',
        author: _currentUser,
        message: 'The module dependency graph is easy to follow.',
      ),
    ],
    'post-2': [],
  };

  var _nextCommentId = 2;

  Future<User> fetchUser(String userId) async {
    await _simulateLatency();
    return _users.firstWhere((user) => user.id == userId);
  }

  Future<List<Post>> fetchFeed(String userId) async {
    await _simulateLatency();
    _users.firstWhere((user) => user.id == userId);
    return List.unmodifiable(_posts);
  }

  Future<Post> fetchPost(String postId) async {
    await _simulateLatency();
    return _posts.firstWhere((post) => post.id == postId);
  }

  Future<List<Comment>> fetchComments(String postId) async {
    await _simulateLatency();
    return List.unmodifiable(_comments[postId] ?? const []);
  }

  Future<Comment> createComment({
    required String postId,
    required User author,
    required String message,
  }) async {
    await _simulateLatency();
    final comment = Comment(
      id: 'comment-${_nextCommentId++}',
      postId: postId,
      author: author,
      message: message,
    );
    (_comments[postId] ??= []).add(comment);
    return comment;
  }

  Future<void> _simulateLatency() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}
