import 'user.dart';

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.message,
  });

  final String id;
  final String postId;
  final User author;
  final String message;
}
