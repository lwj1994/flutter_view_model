// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

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
