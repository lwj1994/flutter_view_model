import 'user.dart';

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.caption,
    required this.likeCount,
  });

  final String id;
  final User author;
  final String caption;
  final int likeCount;
}
