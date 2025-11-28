// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example.dart';

// **************************************************************************
// ViewModelProviderGenerator
// **************************************************************************

final counterViewModelProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

final userViewModelProvider = ViewModelProvider.arg<UserViewModel, Repository>(
  builder: (Repository repo) => UserViewModel(repo),
);

final userKeyViewModelProvider =
    ViewModelProvider.arg<UserKeyViewModel, Repository>(
  builder: (Repository repo) => UserKeyViewModel(repo),
  key: (Repository repo) => repo,
  tag: (Repository repo) => 'user_key',
);
