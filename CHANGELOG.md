## 0.4.2
* Support find existing ViewModel by tag

set tag in `ViewModelFactory.getTag()`:
```dart
class MyViewModelFactory extends ViewModelFactory<MyViewModel> {
  
  @override
  Object? getTag(){
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

