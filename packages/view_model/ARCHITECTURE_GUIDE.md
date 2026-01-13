# 🏗️ Architecture & Best Practices Guide

> **Building scalable, testable Flutter apps with view_model**
>
> This guide shows you how to leverage the **"Everything is ViewModel"** philosophy for clean architecture.

---

## 💡 Core Philosophy: "Everything is ViewModel"

In `view_model`, business logic lives outside the UI—and every layer can benefit from ViewModel capabilities. By using **`with ViewModel`**, any class gets unified access, automatic lifecycle management, and zero-friction dependency coordination through the **Vef (Custom Ref)** framework.

**Key principle**: Whether it's a Repository, Service, or Domain ViewModel—just add `with ViewModel` to gain superpowers! 🚀

---

## 🏛️ Layered Architecture

### 1️⃣ Data Layer (Repositories)

**Purpose**: Handle networking, local storage, and data transformation.

**Pattern**: Use **`with ViewModel`** to access global state (like Auth tokens) without passing dependencies through constructors.

```dart
@genProvider
class UserRepository with ViewModel {
  final ApiClient _api;

  UserRepository(this._api);

  Future<User> getUser() async {
    // Direct access to auth state via built-in vef!
    final authVM = vef.read(authProvider);
    return _api.get('/me', headers: {'Auth': authVM.token});
  }

  Future<void> updateUser(User user) async {
    final authVM = vef.read(authProvider);
    await _api.put('/users/${user.id}', user.toJson(),
      headers: {'Auth': authVM.token}
    );
  }
}
```

**Why this works**:
- ✅ No constructor pollution with auth dependencies
- ✅ Repositories can coordinate with global state cleanly
- ✅ Testable via `setProxy` for mocking auth

---

### 2️⃣ Domain Layer (ViewModels)

**Purpose**: Coordinate between data layer and UI, manage business logic and state.

**Pattern**: Use **`StateViewModel<T>`** for immutable state, or **`with ViewModel`** for simple mutable state.

#### Immutable State Pattern (Recommended)

```dart
@genProvider
class ProfileViewModel extends StateViewModel<ProfileState> {
  final UserRepository _repo;

  ProfileViewModel(this._repo) : super(state: ProfileState.initial());

  Future<void> load() async {
    setState(state.copyWith(isLoading: true));

    try {
      final user = await _repo.getUser();
      setState(state.copyWith(user: user, isLoading: false));
    } catch (e) {
      setState(state.copyWith(error: e.toString(), isLoading: false));
    }
  }

  Future<void> updateProfile(String name) async {
    final updated = state.user!.copyWith(name: name);
    await _repo.updateUser(updated);
    setState(state.copyWith(user: updated));
  }
}
```

#### Mutable State Pattern (Simple Cases)

```dart
@genProvider
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);  // Auto-notifies listeners
  }
}
```

**Coordination between ViewModels**:

```dart
class CartViewModel with ViewModel {
  void checkout() {
    // Access other ViewModels directly via built-in vef
    final userVM = vef.read(userProvider);
    final paymentVM = vef.read(paymentProvider);

    processOrder(userVM.user, paymentVM.method);
  }
}
```

---

### 3️⃣ Presentation Layer (Widgets)

**Purpose**: Display UI and handle user interactions.

**Pattern**: Mix in **`ViewModelStateMixin`** to your State classes.

```dart
class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with ViewModelStateMixin {

  @override
  void initState() {
    super.initState();
    // Load data on page open
    vef.read(profileProvider).load();
  }

  @override
  Widget build(BuildContext context) {
    // Auto-rebuilds when state changes
    final vm = vef.watch(profileProvider);

    if (vm.state.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(vm.state.user?.name ?? 'Profile')),
      body: Column(
        children: [
          Text('Email: ${vm.state.user?.email}'),
          ElevatedButton(
            onPressed: () => _showEditDialog(vm),
            child: Text('Edit Profile'),
          ),
        ],
      ),
    );
  }
}
```

---

## ✅ Best Practices

### 1. Use `with` instead of `extends`

**Why?** Dart 3 mixins enable composition over inheritance—more flexible and keeps your class hierarchy clean.

```dart
// ✅ Recommended
@genProvider
class MyLogic with ViewModel { ... }

// ⚠️ Works but less flexible
@genProvider
class MyLegacyLogic extends ViewModel { ... }
```

---

### 2. Choose the Right Method

| Context | Method | Why |
|---------|--------|-----|
| Inside `build()` | `vef.watch()` | Rebuilds widget when data changes |
| Event handlers (`onPressed`) | `vef.read()` | Just access, no rebuild needed |
| Side effects (navigation) | `vef.listen()` | React to changes without rebuilding |
| Access shared instances | `vef.watchCached(key:)` | Get specific instance by key |

**Example**:

```dart
class _MyPageState extends State<MyPage> with ViewModelStateMixin {
  @override
  void initState() {
    super.initState();

    // Listen for side effects
    vef.listen(authProvider, (auth) {
      if (!auth.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch for rebuilds
    final vm = vef.watch(profileProvider);

    return ElevatedButton(
      // Read for actions
      onPressed: () => vef.read(profileProvider).refresh(),
      child: Text(vm.state.user?.name ?? 'Guest'),
    );
  }
}
```

---

### 3. Share State with Keys

**Default behavior**: Isolated instances per widget.

**Shared state**: Add a `key` to share the same instance across widgets.

```dart
// Global singleton
final authProvider = ViewModelProvider(
  builder: () => AuthViewModel(),
  key: 'auth',
  aliveForever: true,
);

// Shared by ID
final productProvider = ViewModelProvider.arg<ProductViewModel, String>(
  builder: (id) => ProductViewModel(id),
  key: (id) => 'product_$id',  // Same ID = same instance
);
```

---

### 4. Keep State Immutable

When using `StateViewModel`, always treat state as immutable. Use `copyWith` for updates.

**Why?** Predictable rebuilds, easier debugging, time-travel debugging support.

```dart
// ❌ Wrong - mutating state
void badUpdate() {
  state.count++;  // DON'T DO THIS
  setState(state);
}

// ✅ Correct - creating new state
void goodUpdate() {
  setState(state.copyWith(count: state.count + 1));
}
```

**Pro tip**: Use [Freezed](https://pub.dev/packages/freezed) to auto-generate immutable classes with `copyWith`:

```dart
@freezed
class ProfileState with _$ProfileState {
  factory ProfileState({
    User? user,
    @Default(false) bool isLoading,
    String? error,
  }) = _ProfileState;

  factory ProfileState.initial() => ProfileState();
}
```

---

### 5. Handle Lifecycle Hooks

ViewModels provide lifecycle hooks for initialization and cleanup:

```dart
class MyViewModel with ViewModel {
  late StreamSubscription _subscription;

  @override
  void onCreate() {
    super.onCreate();
    // Initialize resources
    _subscription = someStream.listen(_handleData);
  }

  @override
  void onDispose() {
    // Clean up resources
    _subscription.cancel();
    super.onDispose();
  }
}
```

**Even easier**: Use `addDispose` for automatic cleanup:

```dart
class MyViewModel with ViewModel {
  @override
  void onCreate() {
    super.onCreate();

    final subscription = someStream.listen(_handleData);
    addDispose(() => subscription.cancel());  // Auto-cleaned on dispose
  }
}
```

---

## 🧪 Testing Strategy

### Unit Testing ViewModels

Test business logic without Flutter:

```dart
void main() {
  test('increments counter', () {
    final vm = CounterViewModel();
    vm.increment();
    expect(vm.count, 1);
  });

  test('loads user data', () async {
    final mockRepo = MockUserRepository();
    when(mockRepo.getUser()).thenAnswer((_) async => testUser);

    final vm = ProfileViewModel(mockRepo);
    await vm.load();

    expect(vm.state.user, testUser);
    expect(vm.state.isLoading, false);
  });
}
```

---

### Widget Testing with Mocks

Use `setProxy` to swap real ViewModels with mocks:

```dart
testWidgets('shows loading indicator', (tester) async {
  final mockVM = MockProfileViewModel();
  when(mockVM.state).thenReturn(ProfileState(isLoading: true));

  // Replace real ViewModel with mock
  profileProvider.setProxy(ViewModelProvider(builder: () => mockVM));

  await tester.pumpWidget(MyApp());
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

**Don't forget to clean up**:

```dart
tearDown(() {
  profileProvider.clearProxy();
});
```

---

### Testing ViewModels that Use Other ViewModels

When your ViewModel uses `vef` internally, create a test Vef context:

```dart
class TestVef with Vef {}

void main() {
  test('CartViewModel uses UserViewModel', () {
    final testVef = TestVef();

    // Mock dependencies
    final mockUserVM = MockUserViewModel();
    when(mockUserVM.user).thenReturn(testUser);
    userProvider.setProxy(ViewModelProvider(builder: () => mockUserVM));

    // Create ViewModel through Vef context
    final cartVM = testVef.read(cartProvider);
    cartVM.checkout();

    verify(mockUserVM.user).called(1);

    testVef.dispose();
  });
}
```

---

## ⚠️ Common Pitfalls

### ❌ Accessing `vef` in Constructor

**Problem**: `vef` is only available after `onCreate` is called.

```dart
// ❌ Wrong
class BadViewModel with ViewModel {
  BadViewModel() {
    final auth = vef.read(authProvider);  // ERROR: vef not ready!
  }
}

// ✅ Correct
class GoodViewModel with ViewModel {
  @override
  void onCreate() {
    super.onCreate();
    final auth = vef.read(authProvider);  // OK: vef is ready
  }
}
```

---

### ❌ Forgetting to Notify Listeners

**Problem**: UI doesn't update after state changes.

```dart
// ❌ Wrong
class BadViewModel with ViewModel {
  int count = 0;
  void increment() {
    count++;  // UI won't update!
  }
}

// ✅ Correct - Option 1
class GoodViewModel with ViewModel {
  int count = 0;
  void increment() {
    count++;
    notifyListeners();  // Manual notification
  }
}

// ✅ Correct - Option 2 (Recommended)
class BetterViewModel with ViewModel {
  int count = 0;
  void increment() {
    update(() => count++);  // Automatic notification
  }
}
```

---

### ❌ Using `vef.watch` in Callbacks

**Problem**: Unnecessary widget rebuilds.

```dart
// ❌ Wrong - watch in callback
FloatingActionButton(
  onPressed: () {
    vef.watch(counterProvider).increment();  // Wasteful!
  },
)

// ✅ Correct - read in callback
FloatingActionButton(
  onPressed: () {
    vef.read(counterProvider).increment();  // Efficient!
  },
)
```

---

### ❌ Mutating State Objects

**Problem**: `StateViewModel` won't detect changes if you mutate the same object.

```dart
// ❌ Wrong
class BadViewModel extends StateViewModel<MyState> {
  void update() {
    state.count++;  // Mutating same object
    setState(state);  // Won't trigger rebuild!
  }
}

// ✅ Correct
class GoodViewModel extends StateViewModel<MyState> {
  void update() {
    setState(state.copyWith(count: state.count + 1));  // New object
  }
}
```

---

## 📊 Architecture Decision Matrix

When choosing patterns, use this guide:

| Scenario | Pattern | Why |
|----------|---------|-----|
| Simple counter/toggle | `with ViewModel` + mutable state | Minimal overhead |
| Complex state with validation | `StateViewModel<T>` + Freezed | Type-safe, immutable |
| Global auth/settings | `with ViewModel` + `aliveForever: true` | Singleton pattern |
| Data fetching | Repository `with ViewModel` | Access global state cleanly |
| Multi-step forms | `StateViewModel<T>` with stepped state | Track progress immutably |
| Real-time updates | `with ViewModel` + Stream listeners | Reactive data flow |

---

## 🎯 Quick Reference

### Layer Summary

```
┌─────────────────────────────────────────────┐
│  Presentation Layer (Widgets)               │
│  ✓ ViewModelStateMixin                      │
│  ✓ vef.watch() in build()                   │
│  ✓ vef.read() in callbacks                  │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Domain Layer (ViewModels)                  │
│  ✓ with ViewModel or extends StateViewModel │
│  ✓ Business logic & state management        │
│  ✓ Coordinates between repositories         │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Data Layer (Repositories)                  │
│  ✓ with ViewModel                           │
│  ✓ API calls, local storage                 │
│  ✓ Access global state via vef.read()       │
└─────────────────────────────────────────────┘
```

---


*This guide is a living document. Have a better pattern? Open a PR!* 🚀
