# Reddit Post for view_model

## Title Options (choose one):

1. `A Flutter-native state management that actually feels like Flutter`
2. `view_model: State management built for Flutter's class-oriented nature (not ported from web frameworks)`
3. `Finally - a state management that embraces Flutter's OOP style instead of fighting it`

---

## Post Content:

```markdown
Hey r/FlutterDev!

I've been working on **[view_model](https://pub.dev/packages/view_model)** - a **Flutter-native state management** solution that works **with** Flutter's class-oriented nature, not against it.

It's been running my production app (1M+ daily users) for a while now, so I figured it's time to share.

## The core idea

**Flutter-native style: just add a mixin.**

```dart
class _PageState extends State<Page> with ViewModelStateMixin {
  @override
  Widget build(context) {
    final vm = vef.watch(counterProvider);
    return Text('${vm.count}');
  }
}
```

No wrapping your root widget. No special initialization. No fighting with your existing architecture.

---

## Why I built this

But more fundamentally, I felt like a lot of solutions were bringing **frontend web patterns** into Flutter without considering if they actually fit.

Flutter is **class-oriented**. It's built around OOP. Yet many popular solutions push you away from that - functions everywhere, reactive primitives, data graphs.

I wanted something that works **with** Flutter's nature:
- Classes as first-class citizens (literally - `with ViewModel` on **any** class)
- Object-oriented composition, not functional composition
- Built for Flutter's widget lifecycle, not ported from React/Vue/Solid

---

## What's different?

### Any class can be a ViewModel

I got tired of state management being locked to widgets. With view_model, your **repositories, services, background tasks** - they can all be ViewModels:

```dart
class UserRepository with ViewModel {
  Future<User> fetchUser() async {
    // No need to pass auth around - just grab it
    final token = vef.read(authProvider).token;
    return api.getUser(token);
  }
}
```

No BuildContext dependency. No widget tree gymnastics.

---

### ViewModels talking to ViewModels

This was a game-changer for me. Complex flows become way cleaner:

```dart
class CheckoutViewModel with ViewModel {
  void processOrder() {
    final user = vef.read(userProvider).currentUser;
    final cart = vef.read(cartProvider).items;
    final payment = vef.read(paymentProvider);
    
    payment.charge(user, cart);
  }
}
```

Everything's explicit. No magic. Easy to test.

---

### Fine-grained updates when you need them

Sometimes you don't want to rebuild everything. I've got two approaches:

**For StateViewModel:**
```dart
StateViewModelValueWatcher<UserState>(
  viewModel: vm,
  selectors: [
    (state) => state.name,
    (state) => state.age,
  ],
  builder: (state) => Text('${state.name}, ${state.age}'),
)
```

**For simple cases:**
```dart
final counter = ObservableValue<int>(0);

ObserverBuilder(
  observable: counter,
  builder: (count) => Text('$count'),
)

counter.value++;  // boom, updated
```

Both let you update just what changed, not the whole tree.

---

## Quick example

Here's the full flow:

```dart
// 1. Your business logic
class CounterViewModel with ViewModel {
  int count = 0;
  void increment() => update(() => count++);
}

// 2. Register it
final counterProvider = ViewModelProvider<CounterViewModel>(
  builder: () => CounterViewModel(),
);

// 3. Use it
class _PageState extends State<Page> with ViewModelStateMixin {
  @override
  Widget build(context) {
    final vm = vef.watch(counterProvider);
    return FloatingActionButton(
      onPressed: vm.increment,
      child: Text('${vm.count}'),
    );
  }
}
```

That's it. No ceremony.

---

## Details

- **Package**: [pub.dev/packages/view_model](https://pub.dev/packages/view_model)
- **Source**: [github.com/lwj1994/flutter_view_model](https://github.com/lwj1994/flutter_view_model)
- **Size**: ~6K lines
- **Tests**: 95%+ coverage
- **Dependencies**: Just 3 (flutter, meta, stack_trace)

Would love to hear what you think. Happy to answer questions!

---

*Works great with Freezed, go_router, or whatever you're already using.*
```

---

## Publishing Tips:

- **Subreddit**: r/FlutterDev
- **Flair**: "Package" or "Show & Tell"
- **Best time**: US East Coast 8-10 AM or Europe 2-4 PM
- **Engagement**: Reply to comments within the first 2 hours for better visibility
