<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model

> The missing ViewModel in Flutter — Everything is ViewModel.

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://pub.dev/packages/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://pub.dev/packages/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://pub.dev/packages/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](https://github.com/lwj1994/flutter_view_model/blob/main/README_ZH.md)


## Why view_model?

**Everything can be a ViewModel, and any class can get ViewModels everywhere.**

Other solutions force you to choose:
- Global state (shared everywhere)
- Manual providers (boilerplate + BuildContext hell)

**view_model** gives you both:

* ✅ **Everything is ViewModel** - Repository, Service, any class
* ✅ **Get anywhere, no BuildContext** - Access ViewModels from anywhere
* ✅ **Isolated by default** - Each widget gets its own instance
* ✅ **Share when needed** - Use `key` for explicit sharing
* ✅ **Zero boilerplate** - No manual setup
* ✅ **Auto lifecycle** - Auto create & dispose

## Installation

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version # Optional, easier to use
```

## Quick Start

### 1. Define a ViewModel

Create a class extending `ViewModel`. Use `update()` to notify widgets of changes.

```dart
class CounterViewModel extends ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);
  }
}
```

### 2. Create a Provider

Define a global provider. This is how widgets find your ViewModel.

```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);
```

*(Tip: Use `view_model_generator` to skip this step!)*

### 3. Use in Widget

Use `ViewModelStateMixin` in your `StatefulWidget`.

```dart
class CounterPage extends StatefulWidget {
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // Watch the provider. Widget rebuilds when ViewModel updates.
    final vm = vef.watch(counterProvider);

    return Scaffold(
      body: Center(
        child: Text('${vm.count}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: vm.increment,
        child: Icon(Icons.add),
      ),
    );
  }
}
```

## Features

### 1. Universal Access with `Vef`

**Key Concept**: `Vef` is a **mixin** that can be used in **any class** - not just widgets!

The `vef` object (ViewModel Execution Framework) is your gateway to accessing ViewModels anywhere in your code.

#### In Widgets (Built-in)

When you use `ViewModelStateMixin`, you automatically get `vef`:

```dart
class MyPage extends StatefulWidget {
  // ...
}

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider); // vef is available here
    return Text(vm.data);
  }
}
```

#### In ViewModels (Built-in)

**ViewModels already have `vef` built-in!** You can access other ViewModels directly:

```dart
// ✅ ViewModel accessing other ViewModels
class CartViewModel extends ViewModel {
  void checkout() {
    // ViewModels have vef built-in - no need to "with Vef"!
    final userVM = vef.read(userProvider);
    final paymentVM = vef.read(paymentProvider);

    processOrder(userVM.user, paymentVM.method);
  }
}

class UserViewModel extends StateViewModel<UserState> {
  void updateTheme() {
    // Access global settings ViewModel
    final settingsVM = vef.read(settingsProvider);
    applyTheme(settingsVM.state.theme);
  }
}
```

#### In Any Class - "Everything is ViewModel"

**Philosophy**: Any component in your app can be a ViewModel! Repositories, Services, Helpers - they can all extend `ViewModel` to gain access to other ViewModels without `BuildContext`.

```dart
// ✅ Repository as ViewModel
class UserRepository extends ViewModel {
  Future<User> fetch() async {
    final authVM = vef.read(authProvider);
    return api.get('/user', token: authVM.token);
  }
}

// ✅ Service as ViewModel
class AnalyticsService extends ViewModel {
  void trackEvent(String event) {
    final userVM = vef.read(userProvider);
    analytics.log(event, userId: userVM.userId);
  }
}

// ✅ Test helper as ViewModel
class TestHelper extends ViewModel {
  void setupTestData() {
    final authVM = vef.read(authProvider);
    authVM.loginAsTestUser();
  }
}
```

**ViewModels coordinate with each other**:

```dart
class UserProfileViewModel extends ViewModel {
  final UserRepository _repo;
  UserProfileViewModel(this._repo);

  Future<void> loadUser() async {
    // Access other ViewModels via built-in vef
    final authVM = vef.read(authProvider);
    final user = await _repo.fetch(); // Repo uses vef internally

    // Notify other ViewModels
    vef.read(cacheProvider).updateCache(user);
  }
}
```

**Why "Everything is ViewModel"**:
- ✅ **No BuildContext needed** - access ViewModels anywhere
- ✅ **Unified DI** - every component uses the same pattern
- ✅ **Automatic lifecycle** - reference counting works for all
- ✅ **Testable** - mock any ViewModel in your tests
- ✅ **Flexible** - choose what fits your architecture

#### Vef Methods

| Method | Usage |
| :--- | :--- |
| `vef.watch(provider)` | **Access + Listen**. Returns the instance and subscribes to updates (rebuilding the widget). Safe to use in `build()` or `initState()`. |
| `vef.read(provider)` | **Access only**. Returns the instance without subscribing. Does NOT trigger rebuilds. Use this in callbacks (like `onPressed`) or non-widget classes. |
| `vef.listen(provider, onChanged:)` | **Listen only**. Subscribe to changes to run side-effects (like showing a dialog) without rebuilding. Auto-disposed. |
| `vef.watchCached(key:)` | Access an existing cached instance by key (does not create new). |
| `vef.readCached(key:)` | Read an existing cached instance without listening. |

### 2. Immutable State (`StateViewModel`)

For complex state, it's better to use immutable objects. `StateViewModel` is designed for this.

```dart
// 1. The State Class (with copyWith)
class UserState {
  final String name;
  final bool isLoading;

  UserState({this.name = '', this.isLoading = false});

  // Required: copyWith method for immutable updates
  UserState copyWith({String? name, bool? isLoading}) {
    return UserState(
      name: name ?? this.name,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// 2. The ViewModel
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel() : super(state: UserState());

  void loadUser() async {
    setState(state.copyWith(isLoading: true)); // Update state
    // ... fetch api ...
    setState(state.copyWith(isLoading: false, name: 'Alice'));
  }
}
```

> **Tip**: Use code generation tools like [freezed](https://pub.dev/packages/freezed) or [built_value](https://pub.dev/packages/built_value) to auto-generate `copyWith` methods.

#### Listening to Changes

You can listen to specific state changes to trigger side effects (like showing a specific dialog or navigation), without rebuilding the widget.

```dart
// Listen to specific property
vef.listenStateSelect(
  userProvider,
  selector: (state) => state.isLoading,
  onChanged: (prev, isLoading) {
    if (isLoading) {
      showLoadingDialog();
    } else {
      dismissLoadingDialog();
    }
  },
);

// Listen to full state
vef.listenState(userProvider, onChanged: (prev, state) {
  print('State changed from $prev to $state');
});
```

### 3. Dependency Injection (Arguments)

Often your ViewModel needs external data (like an ID or a Repository). Passing arguments is built-in.

```dart
// Define provider expecting an argument (int id)
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (int id) => UserViewModel(id),
);

// Usage in Widget
final vm = vef.watch(userProvider(123)); // Pass the argument here
```

### 4. Instance Sharing (Keys)

**Default Behavior: Isolation**
When you call `vef.watch(provider)`, you get a **new, private instance** of the ViewModel for that widget. If you use the same provider in another widget, it gets a *different* instance.

**Sharing Behavior: Keys**
To share a ViewModel instance between widgets (e.g., a "Product Detail" and its "Header"), you must explicitly provide a `key`.

**Scenario**: You have a `ProductPage` and need to share the `ProductViewModel` with a child widget `ProductHeader`.

```dart
// 1. Define provider with a key derived from an argument
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id', // Key based on ID
);

// 2. Parent Widget (Page)
class ProductPage extends StatefulWidget {
  final String productId;
  // ...
  build(context) {
    // Creates or finds instance with key 'product_123'
    final vm = vef.watch(productProvider(productId));
    // ...
  }
}

// 3. Child Widget (Header)
class ProductHeader extends StatefulWidget {
  final String productId;
  // ...
  build(context) {
    // Returns the SAME instance as the parent because the key is the same
    final vm = vef.watch(productProvider(productId)); 
    return Text(vm.title);
  }
}
```

### 5. Automatic Lifecycle

`view_model` uses strict reference counting to manage memory.

1.  **Create**: The first time a widget accesses a provider via `watch`, `read`, or `listen`, the ViewModel is created (if not already cached) and the reference count increments.
2.  **Alive**: As long as the widget is mounted, it holds a reference to the ViewModel.
    *   `watch(provider)`: Holds a reference AND listens for updates.
    *   `read(provider)`: Holds a reference (without listening for updates).
    *   `listen(provider)`: Internally calls `read`, so it **ALSO** holds a reference.
3.  **Dispose**: When the widget is disposed, its reference is removed. When the total reference count drops to 0, the ViewModel is automatically disposed (`dispose()` is called).

> **Exception (Keep Alive)**: If you set `aliveForever: true` in your provider, the ViewModel will **NEVER** be automatically disposed, even if the reference count hits 0. It behaves like a global singleton.

### 6. Alive Forever (Global State)

By default, ViewModels are auto-disposed when not used. However, some ViewModels need to live forever (e.g., User Session, App Settings).

You can achieve this by setting `aliveForever: true`. **It is highly recommended to use a `key`** for such ViewModels to ensure they can be uniquely identified and retrieved globally.

#### Manual Definition

```dart
final appSettingsProvider = ViewModelProvider<AppSettingsViewModel>(
  builder: () => AppSettingsViewModel(),
  key: 'app_settings', // Specify a global key
  aliveForever: true, // This instance will never be disposed
);
```

#### Using Generator (Recommended)

```dart
@GenProvider(key: 'app_settings', aliveForever: true)
class AppSettingsViewModel extends ViewModel {}
```

Note: Even if `aliveForever` is true, the ViewModel is still **lazy-loaded**. It will be created the first time it is accessed.

### 7. Architecture Patterns

#### Clean Architecture with Vef

Here's how to structure a real app with `view_model`:

```dart
// ============================================
// 1️⃣ Data Layer - Repository as ViewModel
// ============================================
@GenProvider()
class UserRepository extends ViewModel {
  final ApiClient _api;

  UserRepository(this._api);

  // ✅ Repository is ViewModel - can access other ViewModels
  Future<User> fetchUser(int id) async {
    final authVM = vef.read(authProvider);
    return _api.get('/users/$id',
      headers: {'Authorization': 'Bearer ${authVM.token}'}
    );
  }

  Future<void> updateUser(User user) async {
    final authVM = vef.read(authProvider);
    await _api.put('/users/${user.id}', user.toJson(),
      headers: {'Authorization': 'Bearer ${authVM.token}'}
    );
  }
}

// ============================================
// 2️⃣ Domain Layer - Global & Feature ViewModels
// ============================================
@GenProvider(key: 'auth', aliveForever: true)
class AuthViewModel extends StateViewModel<AuthState> {
  AuthViewModel() : super(state: AuthState.unauthenticated());

  String? get token => state.token;
  bool get isAuthenticated => state.isAuthenticated;

  Future<void> login(String email, String password) async {
    setState(state.copyWith(isLoading: true));
    try {
      final result = await authService.login(email, password);
      setState(AuthState.authenticated(result.token, result.user));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  void logout() {
    setState(AuthState.unauthenticated());
  }
}

@GenProvider()
class UserViewModel extends StateViewModel<UserState> {
  final UserRepository _repository;

  UserViewModel(this._repository) : super(state: UserState.initial());

  Future<void> loadUser(int id) async {
    setState(state.copyWith(isLoading: true));
    try {
      // ✅ Repository handles auth internally via vef
      final user = await _repository.fetchUser(id);
      setState(state.copyWith(user: user, isLoading: false));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> updateProfile(String name) async {
    final updated = state.user!.copyWith(name: name);
    await _repository.updateUser(updated);
    setState(state.copyWith(user: updated));

    // Notify other ViewModels
    vef.read(profileCacheProvider).invalidate();
  }
}

// ============================================
// 3️⃣ Presentation Layer - Widgets
// ============================================
class UserProfilePage extends StatefulWidget {
  final int userId;
  const UserProfilePage({required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with ViewModelStateMixin {

  @override
  void initState() {
    super.initState();
    // Load user data when page opens
    vef.read(userProvider).loadUser(widget.userId);

    // Listen for auth changes (e.g., logout)
    vef.listenStateSelect(
      authProvider,
      selector: (state) => state.isAuthenticated,
      onChanged: (prev, isAuth) {
        if (!isAuth) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userVM = vef.watch(userProvider);
    final authVM = vef.watch(authProvider);

    if (userVM.state.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(userVM.state.user?.name ?? 'Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: authVM.logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Text('Name: ${userVM.state.user?.name}'),
          Text('Email: ${userVM.state.user?.email}'),
          ElevatedButton(
            onPressed: () => _showEditDialog(userVM),
            child: Text('Edit Profile'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(UserViewModel vm) {
    // ... show dialog to edit name
    vm.updateProfile(newName);
  }
}
```

**Key Takeaways**:
- 🔹 **"Everything is ViewModel"** - Repository, Services, all can extend ViewModel
- 🔹 **No BuildContext needed** - all components access each other via built-in `vef`
- 🔹 **Repository as ViewModel** - handles its own dependencies (like Auth)
- 🔹 **ViewModels coordinate** - business logic ViewModels use repositories
- 🔹 **Widgets use ViewModelStateMixin** - access everything via `vef`
- 🔹 **Global state** (Auth) uses `aliveForever: true` with a `key`
- 🔹 **Unified DI pattern** - same pattern across all layers

### 8. Code Generation (Recommended)

Writing `ViewModelProvider` definitions manually is boring. Use `@genProvider` to automate it.

```dart
@genProvider
class MyViewModel extends ViewModel {}
```

Run `dart run build_runner build` and it generates the provider for you.
See [view_model_generator](../view_model_generator/README.md) for details.

## Testing

### Widget Tests

You can mock any ViewModel for testing using `setProxy`:

```dart
testWidgets('displays user data', (tester) async {
  final mockVM = MockUserViewModel();
  when(mockVM.state).thenReturn(UserState(user: testUser));

  // Replace the real implementation with the mock
  userProvider.setProxy(
    ViewModelProvider(builder: () => mockVM)
  );

  await tester.pumpWidget(MyApp());

  expect(find.text(testUser.name), findsOneWidget);
});
```

### Unit Tests for Repository ViewModels

You can test repository ViewModels by mocking the providers they depend on:

```dart
void main() {
  late UserRepository repository;
  late MockAuthViewModel mockAuthVM;

  setUp(() {
    mockAuthVM = MockAuthViewModel();
    when(mockAuthVM.token).thenReturn('test-token');

    // Mock the auth provider
    authProvider.setProxy(
      ViewModelProvider(builder: () => mockAuthVM)
    );

    repository = UserRepository(mockApiClient);
  });

  tearDown(() {
    authProvider.clearProxy();
  });

  test('fetchUser includes auth token', () async {
    // The repository uses vef.read(authProvider) internally
    await repository.fetchUser(123);

    // Verify token was used
    verify(mockApiClient.get(
      '/users/123',
      headers: {'Authorization': 'Bearer test-token'}
    ));
  });
}
```

### Testing ViewModels that Depend on Other ViewModels

When testing a ViewModel that uses `vef` internally, you need to create it through a real Vef context:

```dart
// Helper class for tests
class TestVef with Vef {}

void main() {
  test('CartViewModel accesses UserViewModel', () {
    // Create a Vef context for the test
    final testVef = TestVef();

    final mockUserVM = MockUserViewModel();
    when(mockUserVM.user).thenReturn(testUser);

    userProvider.setProxy(
      ViewModelProvider(builder: () => mockUserVM)
    );

    // ✅ Create CartViewModel through Vef so it can access mocked dependencies
    final cartVM = testVef.read(cartProvider);
    cartVM.checkout();

    // Verify the cart accessed the user
    verify(mockUserVM.user).called(1);

    testVef.dispose();
  });
}
```

## Common Pitfalls

### ❌ Missing `key` with `aliveForever`

Without a key, each widget creates a separate instance (defeating the purpose):

```dart
// ❌ Wrong - creates multiple instances
@GenProvider(aliveForever: true)
class AuthViewModel extends ViewModel {}

// ✅ Correct - single shared instance
@GenProvider(key: 'auth', aliveForever: true)
class AuthViewModel extends ViewModel {}
```

### ❌ Using `watch()` in callbacks

This creates a new listener on every call:

```dart
// ❌ Wrong
ElevatedButton(
  onPressed: () {
    final vm = vef.watch(provider);  // New listener each press!
    vm.doSomething();
  },
)

// ✅ Correct
ElevatedButton(
  onPressed: () {
    final vm = vef.read(provider);  // No listening
    vm.doSomething();
  },
)
```

### ❌ Forgetting `copyWith` in State classes

`StateViewModel` requires immutable state with `copyWith`:

```dart
// ❌ Wrong - no copyWith
class MyState {
  final int count;
  MyState(this.count);
}

// ✅ Correct - has copyWith
class MyState {
  final int count;
  MyState(this.count);

  MyState copyWith({int? count}) => MyState(count ?? this.count);
}

// ✅ Better - use freezed/built_value for generation
@freezed
class MyState with _$MyState {
  factory MyState({required int count}) = _MyState;
}
```

## Global Configuration

You can configure global behavior in your `main()` function.

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      // Enable debug logging
      isLoggingEnabled: true,

      // Custom state equality check (optional)
      equals: (prev, current) {
        // Use Equatable or custom logic
        if (prev is Equatable && current is Equatable) {
          return prev == current;
        }
        return identical(prev, current);
      },

      // Handle errors in listeners (NEW in v0.13.0)
      onListenerError: (error, stackTrace, context) {
        // Report to crash analytics
        FirebaseCrashlytics.instance.recordError(error, stackTrace);

        // Or rethrow in debug mode
        if (kDebugMode) {
          print('❌ Error in $context: $error');
          print(stackTrace);
        }
      },

      // Handle errors during disposal (NEW in v0.13.0)
      onDisposeError: (error, stackTrace) {
        print('⚠️ Disposal error: $error');
      },
    ),

    // Add global observers for navigation/lifecycle events
    lifecycles: [
      MyViewModelObserver(),
    ],
  );

  runApp(MyApp());
}

// Custom observer example
class MyViewModelObserver extends ViewModelLifecycle {
  @override
  void onCreate(ViewModel viewModel, InstanceArg arg) {
    print('✅ Created: ${viewModel.runtimeType}');
  }

  @override
  void onDispose(ViewModel viewModel, InstanceArg arg) {
    print('🗑️ Disposed: ${viewModel.runtimeType}');
  }
}
```

**New in v0.13.0**:
- ✨ `onListenerError`: Catch errors in `notifyListeners()` and state listeners
- ✨ `onDisposeError`: Catch errors during resource cleanup
- 🎯 Useful for crash reporting and debugging



## License

MIT License - see [LICENSE](./LICENSE) file.
