import 'dart:async';

import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import '../core/load_phase.dart';
import '../models/comment.dart';
import '../models/post.dart';
import 'post_detail_view_model.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    required this.postId,
    required this.currentUserId,
    super.key,
  });

  final String postId;
  final String currentUserId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage>
    with ViewModelStateMixin<PostDetailPage> {
  PostDetailViewModel get detail => viewModelBinding.watch(
        postDetailViewModelSpec(widget.postId, widget.currentUserId),
      );

  @override
  void initState() {
    super.initState();
    unawaited(detail.load());
  }

  @override
  Widget build(BuildContext context) {
    final detailState = detail.state;
    final commentState = detail.comments.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Post detail')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: commentState.isSubmitting ? null : _composeComment,
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(commentState.isSubmitting ? 'Sending' : 'Comment'),
      ),
      body: switch (detailState.phase) {
        LoadPhase.failure => Center(
            child: Text('Load failed: ${detailState.error}'),
          ),
        LoadPhase.ready => _PostDetailBody(
            post: detailState.post!,
            comments: commentState.comments,
          ),
        LoadPhase.idle || LoadPhase.loading => const Center(
            child: CircularProgressIndicator(),
          ),
      },
    );
  }

  Future<void> _composeComment() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Say something...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null) return;

    try {
      await detail.addComment(message);
    } catch (_) {
      // CommentState already contains the error. A production app could show
      // a Snackbar here.
    }
  }
}

class _PostDetailBody extends StatelessWidget {
  const _PostDetailBody({required this.post, required this.comments});

  final Post post;
  final List<Comment> comments;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            '@${post.author.username}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(post.caption),
          const Divider(height: 32),
          Text(
            'Comments (${comments.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final comment in comments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('@${comment.author.username}'),
              subtitle: Text(comment.message),
            ),
        ],
      );
}
