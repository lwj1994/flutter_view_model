import 'package:view_model/view_model.dart';

class AuthService with ViewModel {
  bool isLoggedIn = false;

  void login() => update(() => isLoggedIn = true);
  void logout() => update(() => isLoggedIn = false);
}

final authSpec = ViewModelSpec<AuthService>(
  builder: () => AuthService(),
  key: 'auth_service',
  aliveForever: true, // Keep it alive globally
);

class ProfileViewModel with ViewModel {
  // Dependency injection via viewModelBinding
  // It automatically binds ProfileViewModel's lifecycle to AuthService if needed,
  // but here authSpec is aliveForever.
  late final auth = viewModelBinding.read(authSpec);

  String get status => auth.isLoggedIn ? 'Online' : 'Offline';
}

final profileSpec = ViewModelSpec<ProfileViewModel>(
  builder: () => ProfileViewModel(),
);

// Usage in logic (outside Widgets)
class AppInitializer with ViewModelBinding {
  void checkStatus() {
    final auth = viewModelBinding.read(authSpec);
    print('Initial login status: ${auth.isLoggedIn}');
  }
}
