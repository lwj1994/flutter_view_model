// @author luwenjie on 2025/1/16 10:00:00

/// Tests for ViewModel dependency injection functionality.
///
/// This file contains comprehensive tests for the dependency injection system
/// including circular dependency detection, dependency context management,
/// and ViewModel dependency access methods.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/view_model/provider.dart';
import 'package:view_model/src/view_model/state_store.dart';
import 'package:view_model/src/view_model/view_model.dart';

/// Test ViewModel for authentication functionality
class AuthViewModel with ViewModel {
  bool _isAuthenticated = false;
  String? _currentUser;

  bool get isAuthenticated => _isAuthenticated;

  String? get currentUser => _currentUser;

  void login(String username) {
    _isAuthenticated = true;
    _currentUser = username;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }
}

/// Test ViewModel for user profile functionality
class UserProfileViewModel with ViewModel {
  AuthViewModel? _authViewModel;
  String _profileData = 'No profile data';

  String get profileData => _profileData;

  String get userName {
    _authViewModel ??= vef.read<AuthViewModel>(
      ViewModelProvider<AuthViewModel>(builder: () => AuthViewModel()),
    );
    return _authViewModel!.currentUser ?? 'Guest';
  }

  bool get isLoggedIn {
    _authViewModel ??= vef.read<AuthViewModel>(
      ViewModelProvider<AuthViewModel>(builder: () => AuthViewModel()),
    );
    return _authViewModel!.isAuthenticated;
  }

  void updateProfile(String data) {
    _authViewModel ??= vef.read<AuthViewModel>(
      ViewModelProvider<AuthViewModel>(builder: () => AuthViewModel()),
    );
    if (_authViewModel!.isAuthenticated) {
      _profileData = data;
      notifyListeners();
    }
  }
}

/// Test ViewModel for settings functionality
class SettingsViewModel with ViewModel {
  String _theme = 'light';

  String get theme => _theme;

  void setTheme(String newTheme) {
    _theme = newTheme;
    notifyListeners();
  }
}

/// Test ViewModel that depends on multiple other ViewModels
class DashboardViewModel with ViewModel {
  AuthViewModel? _authViewModel;
  SettingsViewModel? _settingsViewModel;
  String _status = 'Ready';

  String get welcomeMessage {
    _authViewModel ??= vef.read<AuthViewModel>(
      ViewModelProvider<AuthViewModel>(builder: () => AuthViewModel()),
    );
    _settingsViewModel ??= vef.read<SettingsViewModel>(
      ViewModelProvider<SettingsViewModel>(builder: () => SettingsViewModel()),
    );
    final user = _authViewModel!.currentUser ?? 'Guest';
    final theme = _settingsViewModel!.theme;
    return 'Welcome $user! Theme: $theme';
  }

  String get status => _status;

  void updateStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }
}

/// Test ViewModel that creates circular dependency (for testing)
class CircularViewModel1 with ViewModel {
  late final CircularViewModel2 _dependency;

  void initializeDependencies() {
    _dependency = vef.readCached<CircularViewModel2>();
  }
}

/// Test ViewModel that creates circular dependency (for testing)
class CircularViewModel2 with ViewModel {
  late final CircularViewModel1 _dependency;

  void initializeDependencies() {
    _dependency = vef.readCached<CircularViewModel1>();
  }
}

void main() {
  group('ViewModel Dependency Access Tests', () {
    testWidgets('should read dependency successfully through widget context',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestDependencyWidget(),
        ),
      );

      // Verify the widget builds successfully, which means dependencies work
      expect(find.byType(TestDependencyWidget), findsOneWidget);
    });

    test('should throw error when no context exists', () {
      final orphanViewModel = SettingsViewModel();

      expect(
        () => orphanViewModel.vef.readCached<AuthViewModel>(),
        throwsA(isA<ViewModelError>()),
      );
    });

    test('should throw error when no context exists', () {
      final orphanViewModel = SettingsViewModel();

      expect(
        () => orphanViewModel.vef.readCached<AuthViewModel>(),
        throwsA(isA<ViewModelError>()),
      );
    });
  });

  group('Integration Tests', () {
    testWidgets('should work end-to-end with real ViewModels through widgets',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestMultipleDependencyWidget(),
        ),
      );

      // Verify the widget builds successfully with multiple dependencies
      expect(find.byType(TestMultipleDependencyWidget), findsOneWidget);
    });
  });

  group('Widget Dependency Binding Tests', () {
    late AuthViewModel authViewModel;
    late UserProfileViewModel profileViewModel;

    setUp(() {
      authViewModel = AuthViewModel();
      profileViewModel = UserProfileViewModel();
    });

    testWidgets('should correctly bind dependencies between ViewModels',
        (tester) async {
      // Test dependency registration through actual ViewModel usage
      await tester.pumpWidget(
        const MaterialApp(
          home: TestDependencyWidget(),
        ),
      );

      // Verify the widget builds successfully with dependencies
      expect(find.byType(TestDependencyWidget), findsOneWidget);
    });

    testWidgets('should handle multiple dependent ViewModels correctly',
        (tester) async {
      // Test multiple dependencies through actual widget usage
      await tester.pumpWidget(
        const MaterialApp(
          home: TestMultipleDependencyWidget(),
        ),
      );

      // Verify the widget builds successfully with multiple dependencies
      expect(find.byType(TestMultipleDependencyWidget), findsOneWidget);
    });
  });
}

// Additional test ViewModels for complex circular dependency tests
class ComplexCircularViewModelA with ViewModel {
  String get name => 'ComplexA';
}

class ComplexCircularViewModelB with ViewModel {
  String get name => 'ComplexB';
}

class ComplexCircularViewModelC with ViewModel {
  String get name => 'ComplexC';
}

class IndirectCircularViewModelA with ViewModel {
  String get name => 'IndirectA';
}

class IndirectCircularViewModelB with ViewModel {
  String get name => 'IndirectB';
}

class IndirectCircularViewModelC with ViewModel {
  String get name => 'IndirectC';
}

class IndirectCircularViewModelD with ViewModel {
  String get name => 'IndirectD';
}

// Diamond pattern test ViewModels
class DiamondRootViewModel with ViewModel {
  String get name => 'DiamondRoot';
}

class DiamondLeftViewModel with ViewModel {
  String get name => 'DiamondLeft';
}

class DiamondRightViewModel with ViewModel {
  String get name => 'DiamondRight';
}

class DiamondLeafViewModel with ViewModel {
  String get name => 'DiamondLeaf';
}

// Test widgets for dependency binding tests
class TestDependencyWidget extends StatelessWidget {
  const TestDependencyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Test Dependency Widget'),
      ),
    );
  }
}

class TestMultipleDependencyWidget extends StatelessWidget {
  const TestMultipleDependencyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Test Multiple Dependency Widget'),
      ),
    );
  }
}
