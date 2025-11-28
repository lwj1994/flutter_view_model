import 'package:view_model/view_model.dart';

// Run: dart run build_runner build
// to generate the .vm.dart part file.

part 'example.vm.dart';

/// Example ViewModel annotated for provider generation.
class DemoViewModel extends ViewModel {
  int _count = 0;

  /// Current count value.
  int get count => _count;

  /// Increments the count and notifies listeners.
  void increment() {
    _count++;
    notifyListeners();
  }
}

/// Example dependency used by a ViewModel.
class Repo {}

/// ViewModel with constructor dependency.
@GenProvider()
class UserViewModel extends ViewModel {
  final Repo repo;

  /// Create with repository dependency.
  UserViewModel(this.repo);
}
