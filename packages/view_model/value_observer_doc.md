# `ObservableValue` and `ObserverBuilder` Documentation

This document provides a detailed explanation of `ObservableValue` and the `ObserverBuilder` family of widgets. These components offer a lightweight, reactive state management solution, similar to Flutter's built-in `ValueNotifier` and `ValueListenableBuilder`, but with the added capability of simple state sharing via a `shareKey`.

## `ObservableValue<T>`

`ObservableValue<T>` is an observable data holder. It wraps a single value and notifies its listeners when the value changes.

### Definition

```dart
class ObservableValue<T>
```

### Purpose

It holds a value of type `T`. When this value is modified, any listening widgets, such as `ObserverBuilder`, are triggered to rebuild.

### Constructor

```dart
ObservableValue(T initialValue, {Object? shareKey})
```

- **`initialValue`**: The initial value of the observable.
- **`shareKey`**: An optional parameter used to share the state of this `ObservableValue` across different widgets.
  - If a `shareKey` is provided, multiple `ObservableValue` instances with the same key will share the same underlying data state.
  - If no `shareKey` is provided, a unique internal key is created, making its state local and unshared.

### Properties

- **`T get value`**: Retrieves the current value.
- **`set value(T newValue)`**: Sets a new value. If the new value is different from the current one, it updates the internal state and notifies all listeners.

### Example

```dart
// Create a local, non-shared observable
final counter = ObservableValue<int>(0);

// Create a shared observable
final userProfile = ObservableValue<String>("Guest", shareKey: "userProfile");

// Update the value
counter.value = 5;
counter.value++;
```

---

## `ObserverBuilder<T>`

`ObserverBuilder<T>` is a widget that listens to an `ObservableValue` and automatically rebuilds its UI whenever the value changes.

### Definition

```dart
class ObserverBuilder<T> extends StatefulWidget
```

### Purpose

It subscribes to an `ObservableValue` and provides a `builder` function that re-runs every time the observable's value is updated, ensuring the UI always reflects the latest state.

### Constructor

```dart
const ObserverBuilder({
  required this.observable,
  required this.builder,
  Key? key,
})
```

- **`observable`**: The `ObservableValue` instance to listen to.
- **`builder`**: A function that builds the widget. It is re-invoked whenever the `observable`'s value changes.

### Example

```dart
final counter = ObservableValue<int>(0);

// ... in your widget's build method ...
Column(
  children: [
    ObserverBuilder<int>(
      observable: counter,
      builder: (value) {
        // This Text widget will rebuild whenever counter.value changes
        return Text('Counter: ${value}');
      },
    ),
    ElevatedButton(
      onPressed: () {
        counter.value = counter.value + 1;   
     },
      child: Text('Increment'),
    )
  ],
)
```

---

## `ObserverBuilder2<T1, T2>` & `ObserverBuilder3<T1, T2, T3>`

These are specialized versions of `ObserverBuilder` for listening to two or three `ObservableValue`s simultaneously. They rebuild their UI if _any_ of the observed values change.

### Purpose

To efficiently listen to multiple data sources and rebuild a piece of UI that depends on all of them.

### Example

```dart
final firstName = ObservableValue<String>('John');
final lastName = ObservableValue<String>('Doe');

// ...
ObserverBuilder2<String, String>(
  observable1: firstName,
  observable2: lastName,
  builder: (firstName, lastName) {
    return Text('Full Name: ${firstName} ${lastName}');
  },
)
```

---

## Core Mechanism: State Sharing with `shareKey`

The key feature that distinguishes `ObservableValue` is its simple state-sharing mechanism.

### How It Works

When you create an `ObservableValue` with a `shareKey`, it uses that key to register or retrieve a shared `_ObserveDataViewModel` instance from the `view_model` package's dependency injection system.

- **Shared State**: All `ObservableValue` instances and `ObserverBuilder`s that use the **same `shareKey`** will point to the **same underlying `ViewModel`**.
- **Automatic Updates**: When the value of one shared `ObservableValue` is updated, the underlying `ViewModel`'s state changes. This automatically notifies all other `ObservableValue`s and `ObserverBuilder`s sharing that key, causing them to update and rebuild.

### Example

Imagine you have two different widgets in your app that need to display and modify a shared counter.

```dart
// --- Widget A ---
final sharedCounterA = ObservableValue<int>(0, shareKey: 'global_counter');

ObserverBuilder<int>(
  observable: sharedCounterA,
  builder: (value) => Text('Counter in A: ${value}'),
);
ElevatedButton(
  onPressed: () => sharedCounterA.value++,
  child: Text('Increment from A'),
);


// --- Widget B (perhaps on a different screen) ---
final sharedCounterB = ObservableValue<int>(0, shareKey: 'global_counter');

ObserverBuilder<int>(
  observable: sharedCounterB,
  builder: (value) => Text('Counter in B: ${value}'),
);
```

In this scenario:

- When the button in Widget A is pressed, `sharedCounterA.value` is incremented.
- Because both `sharedCounterA` and `sharedCounterB` use the same `shareKey`, the `Text` widget in **both** Widget A and Widget B will rebuild to show the new value.

### Internal Implementation

- `ObservableValue` acts as a user-friendly wrapper around the `view_model`'s `StateViewModel`.
- The `shareKey` is used as the `key` for the `watchViewModel` function, enabling instance sharing and lifecycle management provided by the `view_model` package.
- This design makes `ObservableValue` a lightweight and intuitive tool for both local and shared state management.
