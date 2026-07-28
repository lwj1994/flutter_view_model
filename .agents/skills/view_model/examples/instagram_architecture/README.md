# Instagram Multi-Module Architecture Example

This is a complete Flutter example organized by functional module. The entry
point is [`main.dart`](./main.dart). Copy the entire directory into a Flutter
project's `lib/` directory to run it.

## Directory Structure

```text
instagram_architecture/
├── main.dart
├── app/
│   ├── init_view_model.dart       # Startup flow coordination
│   └── instagram_app.dart         # App root binding
├── core/
│   ├── instagram_api.dart         # Shared API ViewModel
│   └── load_phase.dart
├── models/
│   ├── comment.dart
│   ├── post.dart
│   └── user.dart
├── user/
│   ├── user_repo.dart
│   └── user_view_model.dart
├── post/
│   └── post_repo.dart             # Shared by feed and post detail
├── feed/
│   ├── post_feed_page.dart
│   └── post_feed_view_model.dart
├── comment/
│   ├── comment_repo.dart
│   └── comment_view_model.dart
└── post_detail/
    ├── post_detail_page.dart
    └── post_detail_view_model.dart
```

## Dependency Graph

```text
InstagramApp binding
└── InitViewModel(currentUserId)
    ├── UserViewModel(currentUserId)
    │   └── UserRepo ───────────────┐
    └── PostFeedViewModel(userId)   │
        └── PostRepo ───────────────┤
                                    └── InstagramApi

PostDetailPage binding
└── PostDetailViewModel(postId, currentUserId)
    ├── PostRepo (shared with Feed)
    └── CommentViewModel(postId, currentUserId)
        ├── UserViewModel (shared with startup flow)
        └── CommentRepo ── InstagramApi (same instance)
```

## Key Design Decisions

- The API, repositories, feature state, and startup coordinator are managed
  ViewModels. Plain data entities are not functional modules, so they remain
  immutable Dart objects.
- Each `ViewModelSpec` lives beside its module. Consumers resolve dependencies
  only through stable specs.
- Every identity-bearing module receives its context explicitly:
  `UserViewModel(userId)`, `PostFeedViewModel(userId)`,
  `PostDetailViewModel(postId, currentUserId)`, and
  `CommentViewModel(postId, currentUserId)`. Each parameterized spec derives
  its key from those inputs so distinct users and posts remain isolated.
- Repositories stay context-free. IDs are method arguments such as
  `UserRepo.getUser(userId)` and `PostRepo.getFeed(userId)` instead of mutable
  repository fields.
- App-scoped shared modules use explicit keys without `aliveForever`. The app
  root binding and parent-to-child lifecycle edges keep them alive, while the
  final owner leaving still triggers automatic disposal.
- Post detail and comment modules use parameterized `postId` keys. Different
  posts remain isolated, and leaving a detail page releases its dependency
  subtree automatically.
- A module uses `read` when it only calls a child. `PostDetailViewModel` uses
  `watch` for `CommentViewModel` because comment changes must propagate to and
  refresh the detail page.
- Every ViewModel dependency is exposed through a resolver getter. No
  ViewModel is cached in a `late final`, `final`, or `??=` field.
