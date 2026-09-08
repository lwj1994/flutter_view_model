import 'package:flutter/foundation.dart';
import 'package:view_model/view_model.dart';

// Note: This is an example file. To generate the .vm.dart file,
// you need to run:
// dart run build_runner build

part 'example.vm.dart';

@GenSpec()
class CounterViewModel extends ViewModel {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

// Example with dependencies
class Repository {}

@GenSpec()
class UserViewModel extends ViewModel {
  final Repository repo;

  UserViewModel(this.repo);
}

@GenSpec(key: Expression('repo'), tag: 'user_key')
class UserKeyViewModel extends ViewModel {
  final Repository repo;

  UserKeyViewModel(this.repo);
}

// Required super parameters are inputs of the generated spec too.
@GenSpec()
class SeededCounterViewModel extends StateViewModel<int> {
  SeededCounterViewModel({required super.state, required this.step});

  final int step;

  void increment() => setState(state + step);
}

class ItemViewModel extends ViewModel {
  ItemViewModel(this.id);

  final String id;
}

@GenSpec()
class ItemDetailViewModel extends ItemViewModel {
  ItemDetailViewModel(super.id, this.title);

  final String title;
}

// A custom spec factory can supply the parent state itself.
@GenSpec()
class DefaultCounterViewModel extends StateViewModel<int> {
  DefaultCounterViewModel({required super.state});

  factory DefaultCounterViewModel.spec() => DefaultCounterViewModel(state: 0);
}

void main() {
  // Access the generated specs
  // final counterSpec = counterSpec;
  // final userSpec = userSpec;

  debugPrint('Run "dart run build_runner build" to generate the code.');
}
