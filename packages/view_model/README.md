<p align="center">
  <img src="https://lwjlol-images.oss-cn-beijing.aliyuncs.com/logo.png" alt="ViewModel Logo" height="96" />
</p>

# view_model: Flutter-Native State Management

A comprehensive state management solution built specifically for Flutter's widget-based architecture. Combines MVVM patterns with automatic lifecycle management, intelligent performance optimizations, and zero boilerplate.

**Key Highlights:**
- **Flutter-First Design**: Built for Flutter's OOP and widget tree architecture
- **Minimal Boilerplate**: Just add a mixin - no root wrapping or forced inheritance
- **Automatic Lifecycle**: Reference counting and auto-disposal based on widget lifecycle
- **Smart Performance**: Pause mechanism defers updates when widgets aren't visible
- **ViewModel Dependencies**: ViewModels can directly access and watch other ViewModels
- **Fine-Grained Updates**: Field-level reactivity to rebuild only what changed

| Package | Version |
| :--- | :--- |
| **view_model** | [![Pub Version](https://img.shields.io/pub/v/view_model)](https://img.shields.io/pub/v/view_model) |
| **view_model_annotation** | [![Pub Version](https://img.shields.io/pub/v/view_model_annotation)](https://img.shields.io/pub/v/view_model_annotation) |
| **view_model_generator** | [![Pub Version](https://img.shields.io/pub/v/view_model_generator)](https://img.shields.io/pub/v/view_model_generator) |

[![Codecov](https://img.shields.io/codecov/c/github/lwj1994/flutter_view_model/main)](https://app.codecov.io/gh/lwj1994/flutter_view_model/tree/main)

[ChangeLog](https://github.com/lwj1994/flutter_view_model/blob/main/packages/view_model/CHANGELOG.md) | [中文文档](README_ZH.md) | [Architecture Guide](ARCHITECTURE_GUIDE.md)

---

## Agent Skills
See [Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md) for AI Agent usage.

## Why view_model?

This library was developed by a mobile development team (Android, iOS, Flutter) accustomed to MVVM architecture. It provides a native Flutter implementation of the ViewModel concept specifically designed for Flutter's OOP and widget-based architecture.

**Key Differences:**
- **Flutter-Native Design**: Built from the ground up for Flutter's widget tree and lifecycle
- **Low Intrusion**: Add a simple mixin to get started - no root wrapping, no forced widget inheritance
- **ViewModel-to-ViewModel Access**: ViewModels can directly access and depend on other ViewModels
- **Automatic Lifecycle**: Reference counting and automatic disposal based on widget lifecycle
- **Resource-Aware**: Intelligent pause mechanism defers updates when widgets are not visible
- **Fine-Grained Updates**: Rebuild only what changed with field-level reactivity

---

## Installation

```yaml
dependencies:
  view_model: ^latest_version

dev_dependencies:
  build_runner: ^latest_version
  view_model_generator: ^latest_version
```

---

## Quick Start

### 1. Define ViewModel
Use the `ViewModel` mixin for simple ViewModels or extend `StateViewModel<T>` for immutable state management.

**Option A: Simple ViewModel**
```dart
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++); // Notifies listeners
  }
}
```

**Option B: StateViewModel (Recommended)**
```dart
class CounterViewModel extends StateViewModel<CounterState> {
  CounterViewModel() : super(state: const CounterState(count: 0));

  void increment() {
    setState(state.copyWith(count: state.count + 1));
  }
}
```

### 2. Register Provider
```dart
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
  key: "shared-counter", // Optional: share instance across widgets
  aliveForever: false,   // Optional: keep alive even when no watchers
);
```
*Tip: Use `view_model_generator` with `@GenProvider` annotation to automate provider generation.*

### 3. Use in Widget
Apply `ViewModelStateMixin` to your State class to access the `vef` API. For StatelessWidget, use `ViewModelStatelessMixin` (though StatefulWidget is preferred).

```dart
class _CounterPageState extends State<CounterPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    // watch() automatically listens for changes and rebuilds
    final vm = vef.watch(counterProvider);

    return Scaffold(
      body: Center(child: Text('${vm.count}')),
      floatingActionButton: FloatingActionButton(
        // read() for one-time access in callbacks
        onPressed: () => vef.read(counterProvider).increment(),
        child: Icon(Icons.add),
      ),
    );
  }
}
```

**Alternative: Use ViewModelBuilder Widget**
```dart
class CounterPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<CounterViewModel>(
      provider: counterProvider,
      builder: (vm) => Text('${vm.count}'),
    );
  }
}
```

### Comparison

| Solution | Changes Required | Root Wrapping | BuildContext Dependency |
|----------|------------------|---------------|------------------------|
| **view_model** | Add mixin | No | No |
| Provider | InheritedWidget | Yes | Yes |
| Riverpod | ConsumerWidget | Yes | No |
| GetX | Global state | No | No |

---

## Core Features

### 1. Universal Access (Vef)
`Vef` (ViewModel Execution Framework) provides a consistent API to access ViewModels across Widgets, ViewModels, and pure Dart classes.

| Method | Behavior | Use Case |
| :--- | :--- | :--- |
| `vef.watch` | Reactive | Inside `build()`, triggers rebuilds |
| `vef.read` | Direct access | Callbacks, event handlers |
| `vef.listen` | Side effects | Navigation, notifications |
| `vef.listenState` | State Listener | Monitor state transitions |

#### Usage Examples
- **Widgets**: Use `ViewModelStateMixin`.
- **ViewModels**: Built-in access to other ViewModels.
- **Pure Classes**: Use `with Vef`.

```dart
class TaskRunner with Vef {
  void run() {
    final authVM = vef.read(authProvider);
    authVM.checkAuth();
  }
}
```

### 2. Pause Mechanism
To save resources, `view_model` automatically defers UI updates when a widget is not visible (e.g., covered by another route, app in background, or hidden in a TabBar).

**Three Built-in Pause Providers:**
- **AppPauseProvider**: Pauses when app goes to background (`AppLifecycleState.hidden`)
- **PageRoutePauseProvider**: Pauses when route is covered by another route (uses `RouteAware`)
- **TickerModePauseProvider**: Pauses when tab is not visible in `TabBarView`

**Setup (Required for Route-based Pausing):**
```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver], // Enable route-aware pausing
  // ...
)
```

**How it Works:**
- `ViewModelStateMixin` automatically integrates all three providers
- When any provider signals pause, notifications from ViewModels are queued
- A **single rebuild** is triggered when the widget becomes visible again
- Prevents wasted CPU cycles rebuilding invisible widgets

**Custom Pause Control:**
```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  final _customPause = ManualVefPauseProvider();

  @override
  void initState() {
    super.initState();
    addPauseProvider(_customPause); // Add custom pause logic
  }

  void onSomeEvent() {
    _customPause.pause(); // Manually pause updates
  }

  void onOtherEvent() {
    _customPause.resume(); // Manually resume updates
  }
}
```

---

### 3. Fine-Grained Reactivity
Optimize performance by rebuilding only what is necessary.

**StateViewModelValueWatcher: Field-Level Rebuilds**
```dart
class _UserPageState extends State<UserPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.read(userProvider); // Read without watching entire VM

    return Column(
      children: [
        // Only rebuilds when 'name' or 'age' changes
        StateViewModelValueWatcher<UserViewModel, UserState>(
          stateViewModel: vm,
          selectors: [(state) => state.name, (state) => state.age],
          builder: (state) => Text('${state.name}, ${state.age}'),
        ),

        // This widget won't rebuild when name/age changes
        Text('Email: ${vm.state.email}'),
      ],
    );
  }
}
```

**ObservableValue: Standalone Reactive Values**
```dart
// Create observable value (can be shared via shareKey)
final counter = ObservableValue<int>(0, shareKey: 'shared-counter');

// Update value
counter.value = 42;

// Use in widget
ObserverBuilder<int>(
  observable: counter,
  builder: (value) => Text('$value'),
);

// Observe multiple values
ObserverBuilder2<int, String>(
  observable1: counter,
  observable2: username,
  builder: (count, name) => Text('$name: $count'),
);
```

**StateViewModel Listeners: Reactive Dependencies**
```dart
class MyViewModel extends StateViewModel<MyState> {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);

    // Listen to entire state changes
    listenState(onChanged: (prev, curr) {
      print('State changed from $prev to $curr');
    });

    // Listen to specific field changes
    listenStateSelect<int>(
      selector: (state) => state.counter,
      onChanged: (prevValue, currValue) {
        if (currValue > 10) {
          // Trigger side effect
        }
      },
    );
  }
}
```

| Approach | Scope | Best For |
|----------|--------------|----------|
| `vef.watch` | Entire widget | Simple cases |
| `StateViewModelValueWatcher` | Selected fields | Complex states |
| `ObservableValue` + `ObserverBuilder` | Single value | Isolated logic |
| `listenStateSelect` | Side effects | Navigation, analytics |

---

### 4. Dependency Injection & Instance Sharing
Use an explicit argument system for dependency injection and cross-widget instance sharing.

**Basic Instance Sharing:**
```dart
final userProvider = ViewModelProvider<UserViewModel>(
  builder: () => UserViewModel(),
  key: 'current-user', // Same key = same instance across widgets
);
```

**Argument-Based Providers (Up to 4 Args):**
```dart
// Single argument
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (userId) => UserViewModel(userId),
  key: (userId) => 'user_$userId', // Different keys for different users
  tag: (userId) => 'user-data',     // Logical grouping
);

// Usage - each ID gets its own cached instance
final user1 = vef.watch(userProvider(42));
final user2 = vef.watch(userProvider(100));
final user3 = vef.watch(userProvider(42)); // Reuses same instance as user1

// Two arguments
final productProvider = ViewModelProvider.arg2<ProductViewModel, int, String>(
  builder: (id, category) => ProductViewModel(id, category),
  key: (id, category) => 'product_${id}_$category',
);

// Usage
final vm = vef.watch(productProvider(123, 'electronics'));
```

**Finding Shared Instances:**
```dart
// Read cached instance by key
final user = vef.readCached<UserViewModel>(key: 'user_42');

// Watch cached instance (rebuilds on changes)
final user = vef.watchCached<UserViewModel>(key: 'user_42');

// Find all instances with same tag
final allUsers = vef.readCachesByTag<UserViewModel>(tag: 'user-data');

// Safe access (returns null if not found)
final user = vef.maybeReadCached<UserViewModel>(key: 'user_42');
```

**ViewModel-to-ViewModel Dependencies:**
```dart
class UserProfileViewModel extends StateViewModel<UserState> {
  void loadProfile() {
    // Access AuthViewModel without explicit injection
    final auth = vef.read(authProvider);

    if (auth.isLoggedIn) {
      final userId = auth.userId;
      // Load profile data
    }
  }

  void setupReactiveAuth() {
    // Watch another ViewModel - auto-updates when auth changes
    final auth = vef.watch(authProvider);

    // Listen to specific state changes
    auth.listenState(onChanged: (prev, curr) {
      if (!curr.isLoggedIn && prev.isLoggedIn) {
        // Handle logout
      }
    });
  }
}
```

**Code Generation (Recommended):**
```dart
import 'package:view_model_annotation/view_model_annotation.dart';

part 'user_view_model.vm.dart';

@GenProvider(
  key: Expression('userId_\$id'), // String interpolation in keys
  tag: 'user-data',
  aliveForever: false,
)
class UserViewModel extends StateViewModel<UserState> {
  factory UserViewModel.provider(int id) => UserViewModel(id);

  UserViewModel(this.userId) : super(state: UserState());

  final int userId;
}

// Run: dart run build_runner build
// Generates: userProvider with proper arg handling
```

---

### 5. Lifecycle Management
ViewModels have automatic lifecycle management based on widget lifecycle and reference counting.

**Lifecycle Hooks:**
```dart
class MyViewModel extends StateViewModel<MyState> {
  @override
  void onCreate(InstanceArg arg) {
    super.onCreate(arg);
    print('ViewModel created');
    // Initialize resources
  }

  @override
  void onBindVef(InstanceArg arg, String vefId) {
    super.onBindVef(arg, vefId);
    print('Widget started watching (vefId: $vefId)');
    // Called each time a new widget starts watching
  }

  @override
  void onUnbindVef(InstanceArg arg, String vefId) {
    super.onUnbindVef(arg, vefId);
    print('Widget stopped watching (vefId: $vefId)');
    // Called each time a widget stops watching
  }

  @override
  void onDispose(InstanceArg arg) {
    print('ViewModel disposed');
    // Clean up resources
    super.onDispose(arg);
  }
}
```

**Lifecycle Modes:**
- **Auto-Lifecycle (Default)**: ViewModels are created on first use and automatically disposed when the last watcher unbinds
- **Singleton Mode**: Use `aliveForever: true` to keep the instance alive forever (useful for global services like AuthViewModel, ConfigViewModel)
- **Shared Instances**: Use `key` parameter to share the same instance across multiple widgets

```dart
// Auto-disposed when no longer watched
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

// Stays alive forever (singleton)
final authProvider = ViewModelProvider<AuthViewModel>(
  builder: () => AuthViewModel(),
  aliveForever: true, // Never disposed
);

// Shared across widgets, disposed when all watchers unbind
final userProvider = ViewModelProvider.arg<UserViewModel, int>(
  builder: (id) => UserViewModel(id),
  key: (id) => 'user_$id', // Shared by key
);
```

**Manual Lifecycle Control:**
```dart
// Force recreate a ViewModel
vef.recycle(myViewModel);

// Dispose a specific instance manually (rare)
myViewModel.dispose();
```

**Global Lifecycle Observers:**
```dart
void main() {
  // Monitor all ViewModels globally
  ViewModel.addLifecycle(MyGlobalObserver());

  runApp(MyApp());
}

class MyGlobalObserver implements ViewModelLifecycle {
  @override
  void onCreate<T extends ViewModel>(T vm, InstanceArg arg) {
    print('Created: ${vm.runtimeType}');
  }

  @override
  void onDispose<T extends ViewModel>(T vm, InstanceArg arg) {
    print('Disposed: ${vm.runtimeType}');
  }

  // ... other callbacks
}
```

---

## Advanced Features

### 1. Pure Dart Access (No Widgets Required)
Use `Vef` mixin in any Dart class to access ViewModels outside of widgets.

```dart
class StartupTask with Vef {
  Future<void> run() async {
    // Access ViewModels in pure Dart
    final auth = vef.read(authProvider);
    await auth.checkLoginStatus();

    final config = vef.read(configProvider);
    await config.loadRemoteConfig();
  }

  @override
  void dispose() {
    super.dispose(); // Clean up all watched ViewModels
  }
}

// Usage
void main() async {
  final task = StartupTask();
  await task.run();
  task.dispose();

  runApp(MyApp());
}
```

### 2. ChangeNotifier Compatibility
Migrate gradually from ChangeNotifier-based code.

```dart
class MyViewModel extends ChangeNotifierViewModel {
  int count = 0;

  void increment() {
    count++;
    notifyListeners(); // Standard ChangeNotifier API
  }
}

// Works with both view_model features and ChangeNotifier consumers
```

### 3. Zone-Based Dependency Resolution
ViewModels can access other ViewModels in async contexts using Zone-based resolution.

```dart
class MyViewModel extends StateViewModel<MyState> {
  Future<void> fetchData() async {
    final result = await runWithVef(() async {
      // Can access vef in async callbacks
      final auth = vef.read(authProvider);
      return await api.fetchData(auth.token);
    }, vef);

    setState(state.copyWith(data: result));
  }
}
```

### 4. Custom Equality for State
Define custom equality to prevent unnecessary rebuilds.

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      // Custom equality check
      equals: (prev, curr) {
        if (prev is MyState && curr is MyState) {
          return prev.id == curr.id; // Only rebuild if ID changes
        }
        return identical(prev, curr);
      },
    ),
  );

  runApp(MyApp());
}
```

---

## Testing
Mocking is straightforward using `setProxy`. All provider variants support proxying.

**Widget Testing with Mocks:**
```dart
testWidgets('Test UI with mock ViewModel', (tester) async {
  // Create mock
  final mockVM = MockUserViewModel();
  when(mockVM.state).thenReturn(UserState(name: 'Alice'));

  // Replace provider
  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());

  expect(find.text('Alice'), findsOneWidget);

  // Cleanup
  userProvider.clearProxy();
});
```

**Testing Argument-Based Providers:**
```dart
testWidgets('Test with arg provider', (tester) async {
  final mockVM = MockUserViewModel();

  // Proxy arg-based provider
  userProvider.setProxy(
    ViewModelProvider.arg<UserViewModel, int>(
      builder: (_) => mockVM, // Ignore arg, return mock
      key: (id) => 'user_$id',
    ),
  );

  await tester.pumpWidget(MyApp());

  // Test with any user ID - all return the mock
  final vm1 = userProvider(42);
  final vm2 = userProvider(100);

  userProvider.clearProxy();
});
```

**Pure Dart Testing (No Widget Required):**
```dart
test('ViewModel logic test', () {
  // Create custom Vef for testing
  final vef = Vef();

  final vm = vef.watch(counterProvider);

  expect(vm.count, 0);

  vm.increment();
  expect(vm.count, 1);

  // Cleanup
  vef.dispose();
});
```

**StateViewModel Testing:**
```dart
test('State changes emit notifications', () {
  final vm = UserViewModel();
  final states = <UserState>[];

  vm.listenState(onChanged: (prev, curr) {
    states.add(curr);
  });

  vm.setState(UserState(name: 'Alice'));
  vm.setState(UserState(name: 'Bob'));

  expect(states.length, 2);
  expect(states[0].name, 'Alice');
  expect(states[1].name, 'Bob');

  vm.dispose();
});
```

**Testing ViewModel Dependencies:**
```dart
test('ViewModel can access other ViewModels', () {
  final vef = Vef();

  // Setup dependencies
  final auth = vef.watch(authProvider);
  final user = vef.watch(userProvider(123));

  // Auth ViewModel is accessible from user ViewModel
  expect(user.isAuthenticated, true);

  vef.dispose();
});
```

---

## Global Configuration
Initialize in `main()` to customize system behavior:

```dart
void main() {
  ViewModel.initialize(
    config: ViewModelConfig(
      isLoggingEnabled: true,
      equals: (prev, curr) => prev == curr,
      onListenerError: (e, s, c) => logger.error(e, s),
    ),
  );
  runApp(MyApp());
}
```

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `isLoggingEnabled` | `false` | Toggle debug logs |
| `equals` | `identical` | Equality logic for state |
| `onListenerError` | `null` | Global listener error handler |
| `onDisposeError` | `null` | Global disposal error handler |

---

## Best Practices

### 1. Prefer StateViewModel for Complex State
```dart
// Good: Immutable state with StateViewModel
class TodoViewModel extends StateViewModel<TodoState> {
  TodoViewModel() : super(state: const TodoState());

  void addTodo(String title) {
    setState(state.copyWith(
      items: [...state.items, TodoItem(title)],
    ));
  }
}

// Avoid: Mutable state requires manual notifyListeners
class TodoViewModel with ViewModel {
  List<TodoItem> items = [];

  void addTodo(String title) {
    items.add(TodoItem(title));
    notifyListeners(); // Easy to forget
  }
}
```

### 2. Use Keys for Shared Instances
```dart
// Good: Explicit key for sharing
final userProvider = ViewModelProvider<UserViewModel>(
  key: 'current-user',
  builder: () => UserViewModel(),
);

// Good: Dynamic keys for argument-based providers
final productProvider = ViewModelProvider.arg<ProductViewModel, int>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id',
);
```

### 3. Use aliveForever for Global Services
```dart
// Good: Singleton services stay alive
final authProvider = ViewModelProvider<AuthViewModel>(
  builder: () => AuthViewModel(),
  aliveForever: true, // Never disposed
);

final themeProvider = ViewModelProvider<ThemeViewModel>(
  builder: () => ThemeViewModel(),
  aliveForever: true,
);
```

### 4. Separate Read and Watch
```dart
// Good: watch() in build, read() in callbacks
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider); // Rebuilds on changes

    return ElevatedButton(
      onPressed: () {
        // Don't watch in callbacks - causes unnecessary rebuilds
        vef.read(myProvider).doAction();
      },
      child: Text(vm.status),
    );
  }
}
```

### 5. Use listen() for Side Effects
```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  void initState() {
    super.initState();

    // Good: listen() for navigation, dialogs, snackbars
    vef.listen(authProvider, onChanged: (vm) {
      if (vm.isLoggedOut) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(authProvider); // For UI updates
    return Text(vm.userName);
  }
}
```

### 6. Code Generation for Providers
```dart
// Good: Use @GenProvider for automatic generation
@GenProvider()
class CounterViewModel extends StateViewModel<CounterState> {
  factory CounterViewModel.provider() => CounterViewModel();
  // ...
}

// Run: dart run build_runner build
// Generates: counterProvider automatically
```

### 7. Structure Your ViewModels
```dart
// Good: Clear separation of concerns
class UserViewModel extends StateViewModel<UserState> {
  UserViewModel(this.repository) : super(state: const UserState());

  final UserRepository repository;

  // Public API for widgets
  Future<void> loadUser(int id) async {
    setState(state.copyWith(loading: true));
    try {
      final user = await repository.fetchUser(id);
      setState(state.copyWith(user: user, loading: false));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), loading: false));
    }
  }

  // Computed properties
  bool get hasError => state.error != null;
  String get displayName => state.user?.name ?? 'Guest';
}
```

### 8. Testing Strategy
```dart
// Good: Pure unit tests for ViewModel logic
test('loadUser updates state correctly', () async {
  final mockRepo = MockUserRepository();
  when(mockRepo.fetchUser(1)).thenAnswer((_) async => User(name: 'Alice'));

  final vm = UserViewModel(mockRepo);

  await vm.loadUser(1);

  expect(vm.state.user?.name, 'Alice');
  expect(vm.state.loading, false);

  vm.dispose();
});

// Widget tests with mocked ViewModels
testWidgets('Shows user name', (tester) async {
  final mockVM = MockUserViewModel();
  when(mockVM.state).thenReturn(UserState(user: User(name: 'Alice')));

  userProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());

  expect(find.text('Alice'), findsOneWidget);

  userProvider.clearProxy();
});
```

---

## Common Patterns

### 1. Authentication Flow
```dart
// Global auth service
final authProvider = ViewModelProvider<AuthViewModel>(
  builder: () => AuthViewModel(),
  aliveForever: true, // Singleton
);

class AuthViewModel extends StateViewModel<AuthState> {
  AuthViewModel() : super(state: const AuthState());

  Future<void> login(String email, String password) async {
    setState(state.copyWith(loading: true));
    try {
      final token = await authService.login(email, password);
      setState(state.copyWith(
        isLoggedIn: true,
        token: token,
        loading: false,
      ));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), loading: false));
    }
  }

  void logout() {
    setState(const AuthState()); // Reset to initial state
  }
}

// Use in any ViewModel
class UserProfileViewModel extends StateViewModel<UserProfileState> {
  void loadProfile() {
    final auth = vef.read(authProvider);
    if (!auth.state.isLoggedIn) {
      // Handle not logged in
      return;
    }

    // Load profile with auth token
    _fetchProfile(auth.state.token);
  }
}
```

### 2. Pagination
```dart
class ProductListViewModel extends StateViewModel<ProductListState> {
  ProductListViewModel(this.repository)
      : super(state: const ProductListState());

  final ProductRepository repository;

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;

    setState(state.copyWith(loading: true));

    try {
      final newProducts = await repository.fetchProducts(
        page: state.currentPage + 1,
      );

      setState(state.copyWith(
        products: [...state.products, ...newProducts],
        currentPage: state.currentPage + 1,
        hasMore: newProducts.isNotEmpty,
        loading: false,
      ));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), loading: false));
    }
  }
}
```

### 3. Form Validation
```dart
class LoginFormViewModel extends StateViewModel<LoginFormState> {
  LoginFormViewModel() : super(state: const LoginFormState());

  void setEmail(String email) {
    final error = _validateEmail(email);
    setState(state.copyWith(
      email: email,
      emailError: error,
    ));
  }

  void setPassword(String password) {
    final error = _validatePassword(password);
    setState(state.copyWith(
      password: password,
      passwordError: error,
    ));
  }

  bool get isValid =>
      state.emailError == null &&
      state.passwordError == null &&
      state.email.isNotEmpty &&
      state.password.isNotEmpty;

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email is required';
    if (!email.contains('@')) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }
}

// Use with field-level rebuilds
StateViewModelValueWatcher<LoginFormViewModel, LoginFormState>(
  stateViewModel: vm,
  selectors: [(s) => s.email, (s) => s.emailError],
  builder: (state) => TextField(
    decoration: InputDecoration(errorText: state.emailError),
    onChanged: vm.setEmail,
  ),
);
```

### 4. Master-Detail Pattern
```dart
// Master: Product list with shared instances
final productProvider = ViewModelProvider.arg<ProductViewModel, int>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id',
);

// List page watches multiple products
class ProductListPage extends StatefulWidget {
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final ids = [1, 2, 3, 4, 5];

    return ListView.builder(
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final vm = vef.watch(productProvider(ids[index]));
        return ListTile(
          title: Text(vm.state.name),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(productId: ids[index]),
            ),
          ),
        );
      },
    );
  }
}

// Detail page reuses same instance
class _ProductDetailPageState extends State<ProductDetailPage>
    with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(productProvider(widget.productId));
    return Scaffold(
      appBar: AppBar(title: Text(vm.state.name)),
      body: Text(vm.state.description),
    );
  }
}
```

---

## Performance Tips

1. **Use Fine-Grained Reactivity**: Prefer `StateViewModelValueWatcher` over full widget rebuilds
2. **Leverage Pause Mechanism**: Configure `ViewModel.routeObserver` to prevent rebuilds on background pages
3. **Avoid watch() in Callbacks**: Use `vef.read()` instead to prevent unnecessary subscriptions
4. **Use Computed Properties**: Calculate derived values in getters instead of storing in state
5. **Batch State Updates**: Update state once with all changes rather than multiple `setState` calls

---

## Migration Guide

### From Provider
```dart
// Before (Provider)
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MyViewModel>();
    return Text(vm.value);
  }
}

// After (view_model)
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(myProvider);
    return Text(vm.value);
  }
}
```

### From Riverpod
```dart
// Before (Riverpod)
final counterProvider = StateNotifierProvider<Counter, int>(
  (ref) => Counter(),
);

class MyPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}

// After (view_model)
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(counterProvider);
    return Text('${vm.count}');
  }
}
```

### From GetX
```dart
// Before (GetX)
class CounterController extends GetxController {
  var count = 0.obs;
  void increment() => count++;
}

class MyPage extends StatelessWidget {
  final controller = Get.put(CounterController());

  @override
  Widget build(BuildContext context) {
    return Obx(() => Text('${controller.count}'));
  }
}

// After (view_model)
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  Widget build(BuildContext context) {
    final vm = vef.watch(counterProvider);
    return Text('${vm.count}');
  }
}
```

---

## FAQ

### Q: When should I use StateViewModel vs ViewModel mixin?
**A:** Use `StateViewModel<T>` when you need immutable state management with automatic equality checks and state history. Use the `ViewModel` mixin for simpler cases or when migrating from ChangeNotifier. StateViewModel is recommended for most use cases.

### Q: How is this different from Provider/Riverpod/GetX?
**A:**
- **vs Provider**: No need for InheritedWidget, no BuildContext dependency, automatic lifecycle, ViewModel-to-ViewModel access
- **vs Riverpod**: No forced ConsumerWidget, simpler syntax, no complex graph concepts, just add a mixin
- **vs GetX**: Type-safe, no global state pollution, Flutter-native design, better testability, explicit dependencies

### Q: Do I need to wrap my app with a root widget?
**A:** No. Just add `ViewModelStateMixin` to your State classes. Optionally add `ViewModel.routeObserver` to `navigatorObservers` for route-aware pausing.

### Q: Can ViewModels access other ViewModels?
**A:** Yes! ViewModels have built-in `vef` access and can use `vef.read()` or `vef.watch()` to access other ViewModels. Dependencies are automatically tracked.

### Q: How do I share a ViewModel instance across pages?
**A:** Two approaches:
1. Use a provider with `key`:
```dart
final userProvider = ViewModelProvider<UserViewModel>(
  builder: () => UserViewModel(),
  key: 'current-user', // Same key = same instance
);
```
2. Read cached instance directly by key:
```dart
final user = vef.readCached<UserViewModel>(key: 'current-user');
```

### Q: When are ViewModels disposed?
**A:** By default, ViewModels are disposed when the last watcher unbinds (reference counting). Use `aliveForever: true` for singleton services that should never be disposed.

### Q: How do I prevent rebuilds when a page is not visible?
**A:** The pause mechanism is automatic with `ViewModelStateMixin`. Just register `ViewModel.routeObserver`:
```dart
MaterialApp(
  navigatorObservers: [ViewModel.routeObserver],
  // ...
)
```

### Q: Can I use this with StatelessWidget?
**A:** Yes, use `ViewModelStatelessMixin` or `ViewModelBuilder` widget, though `StatefulWidget` with `ViewModelStateMixin` is preferred for automatic lifecycle management.

### Q: How do I test ViewModels?
**A:** Multiple approaches:
1. Pure unit tests: Test ViewModel logic directly without widgets
2. Widget tests with mocks: Use `provider.setProxy()` to replace with mocks
3. Integration tests: Test full widget tree with real ViewModels

### Q: Does this work with code generation?
**A:** Yes! Use `view_model_generator` with `@GenProvider` annotation to automatically generate providers. Supports ViewModels with up to 4 constructor parameters.

### Q: How do I handle async operations?
**A:** Use the `update()` method:
```dart
Future<void> loadData() async {
  await update(() async {
    final data = await repository.fetch();
    _data = data;
  }); // Automatically notifies listeners
}
```

### Q: Can I use this outside of widgets (pure Dart)?
**A:** Yes! Mix in `Vef` to any Dart class:
```dart
class MyService with Vef {
  void doWork() {
    final auth = vef.read(authProvider);
    // Use ViewModels in pure Dart
  }
}
```

### Q: How do I migrate from another state management solution?
**A:** See the [Migration Guide](#migration-guide) section above for specific examples for Provider, Riverpod, and GetX.

### Q: What about performance?
**A:** The library includes several optimizations:
- Pause mechanism defers updates when widgets are not visible
- Fine-grained reactivity with `StateViewModelValueWatcher`
- Reference counting prevents memory leaks
- Zone-based dependency resolution is efficient

### Q: Can I use this with Flutter Web/Desktop?
**A:** Yes! The library works on all Flutter platforms (Mobile, Web, Desktop).

---

## Contributing

Contributions are welcome! Please read the [contributing guidelines](https://github.com/lwj1994/flutter_view_model/blob/main/CONTRIBUTING.md) first.

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/lwj1994/flutter_view_model/blob/main/LICENSE) file for details.

## Links

- [GitHub Repository](https://github.com/lwj1994/flutter_view_model)
- [Pub Package](https://pub.dev/packages/view_model)
- [Architecture Guide](https://github.com/lwj1994/flutter_view_model/blob/main/ARCHITECTURE_GUIDE.md)
- [Chinese Documentation](README_ZH.md)
- [Agent Skills](https://github.com/lwj1994/flutter_view_model/blob/main/skills/view_model/SKILL.md)
- [Issue Tracker](https://github.com/lwj1994/flutter_view_model/issues)
