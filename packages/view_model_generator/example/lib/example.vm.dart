// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'example.dart';

// **************************************************************************
// ViewModelSpecGenerator
// **************************************************************************

final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);

final userSpec = ViewModelSpec.arg<UserViewModel, Repository>(
  builder: (Repository repo) => UserViewModel(repo),
);

final userKeySpec = ViewModelSpec.arg<UserKeyViewModel, Repository>(
  builder: (Repository repo) => UserKeyViewModel(repo),
  key: (Repository repo) => repo,
  tag: (Repository repo) => 'user_key',
);

final seededCounterSpec = ViewModelSpec.arg2<SeededCounterViewModel, int, int>(
  builder: (int state, int step) =>
      SeededCounterViewModel(state: state, step: step),
);

final itemDetailSpec = ViewModelSpec.arg2<ItemDetailViewModel, String, String>(
  builder: (String id, String title) => ItemDetailViewModel(id, title),
);

final defaultCounterSpec = ViewModelSpec<DefaultCounterViewModel>(
  builder: () => DefaultCounterViewModel.spec(),
);
