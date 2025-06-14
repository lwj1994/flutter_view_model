## 0.4.4
* Add `ViewModel.maybeRead`

## 0.4.3

* Add `maybeWatchViewModel` and `maybeReadViewModel`
* update `watchViewModel` find logic

```dart
VM watchViewModel<VM extends ViewModel>({
  ViewModelFactory<VM>? factory,
  String? key,
  Object? tag,
});
```

| Parameter Name | Type                    | Optional | Description                                                                                                                                           |
|----------------|-------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `factory`      | `ViewModelFactory<VM>?` | ✅        | Provides the construction method for the ViewModel. Optional; if an existing instance is not found in the cache, it will be used to create a new one. |
| `key`          | `String?`               | ✅        | Specifies a unique key to support sharing the same ViewModel instance. First, it tries to find an instance with the same key in the cache.            |
| `tag`          | `Object?`               | ✅        | Add a tag for ViewModel instance. get tag by `viewModel.tag`. and  it's used by find ViewModel by `watchViewModel(tag:tag)`.                          |

__🔍 Lookup Logic Priority (Important)__
The internal lookup and creation logic of `watchViewModel` is as follows (executed in priority
order):

1. If a key is passed in:

* First, attempt to find an instance with the same key in the cache.
* If a factory exists, use the factory to get a new instance.
* If no factory is found and no instance is found, an error will be thrown.

2. If a tag is passed in, attempt to find the latest created instance which has the same tag
   in the cache.
3. If nothing passed in, attempt to find the latest created instance of this type
   in the cache.

> __⚠️ If no ViewModel instance of the specified type is found, an error will be thrown. Ensure
that the ViewModel has been correctly created and registered before use.__

## 0.4.2

* Support find existing ViewModel by tag

set tag in `ViewModelFactory.getTag()`:

```dart
class MyViewModelFactory extends ViewModelFactory<MyViewModel> {

  @override
  Object? getTag() {
    return 'tag';
  }
}
```

find existing ViewModel by tag:

```dart
MyViewModel get viewModel => watchViewModel<MyViewModel>(tag: 'tag');
```

## 0.4.1

_Breaking change:_

* Use `recycleViewModel` instead of `refreshViewModel`.

## 0.4.0

_Breaking change:_

* Use `ViewModel` instead of `StatelessViewModel`.
* Use `StateViewModel` instead of `ViewModel`.
* Use either `watchViewModel` or `readViewModel` instead of `getViewModel`/
  `requireExistingViewModel`.
* Use `StateViewModel.listenState` instead of `ViewModel.listen`.
* Use `ViewModel.listen` instead of `ViewModel.addListener`.

* Support `ViewModel.read<T>` to read existing view model globally.

## 0.3.0

* transfer to https://github.com/lwj1994/flutter_view_model. thank
  to [Miolin](https://github.com/Miolin)

