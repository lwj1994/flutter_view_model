import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import '../models/post.dart';
import '../post_detail/post_detail_page.dart';
import '../user/user_view_model.dart';
import 'post_feed_view_model.dart';

class PostFeedPage extends StatefulWidget {
  const PostFeedPage({required this.userId, super.key});

  final String userId;

  @override
  State<PostFeedPage> createState() => _PostFeedPageState();
}

class _PostFeedPageState extends State<PostFeedPage>
    with ViewModelStateMixin<PostFeedPage> {
  PostFeedViewModel get feed =>
      viewModelBinding.watch(postFeedViewModelSpec(widget.userId));

  UserViewModel get user =>
      viewModelBinding.watch(userViewModelSpec(widget.userId));

  @override
  Widget build(BuildContext context) {
    final feedState = feed.state;
    final currentUser = user.state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram VM'),
        actions: [
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('@${currentUser.username}')),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await feed.load(force: true);
          } catch (_) {
            // The ViewModel already exposed the error through PostFeedState.
          }
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: feedState.posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final post = feedState.posts[index];
            return _PostCard(
              post: post,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PostDetailPage(
                    postId: post.id,
                    currentUserId: widget.userId,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(
                  child: Text(post.author.displayName.characters.first),
                ),
                title: Text('@${post.author.username}'),
              ),
              Container(
                height: 220,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: Icon(Icons.photo_camera_outlined, size: 64),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('♥ ${post.likeCount}\n${post.caption}'),
              ),
            ],
          ),
        ),
      );
}
