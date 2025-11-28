import 'package:view_model/view_model.dart';

// Note: This is an example file. To generate the .vm.dart file, you need to run:
// dart run build_runner build

part 'example.vm.dart';

@GenProvider()
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

@GenProvider()
class UserViewModel extends ViewModel {
  final Repository repo;

  UserViewModel(this.repo);
}

@GenProvider(key: Expr('repo'), tag: "user_key")
class UserKeyViewModel extends ViewModel {
  final Repository repo;

  UserKeyViewModel(this.repo);
}

void main() {
  // Access the generated providers
  // final counterProvider = counterProvider;
  // final userProvider = userProvider;

  print('Run "dart run build_runner build" to generate the code.');
}
