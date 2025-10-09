import 'package:view_model/view_model.dart';
import 'counter_state.dart';

class CounterViewModel extends StateViewModel<CounterState> {
  CounterViewModel({required super.state});

  void increment() {
    setState(state.copyWith(
      count: state.count + state.incrementBy,
    ));
  }

  void decrement() {
    setState(state.copyWith(
      count: state.count - state.incrementBy,
    ));
  }

  void setIncrementBy(int value) {
    setState(state.copyWith(incrementBy: value));
  }

  void reset() {
    setState(const CounterState());
  }
}

class CounterViewModelFactory with ViewModelFactory<CounterViewModel> {
  @override
  CounterViewModel build() => CounterViewModel(state: const CounterState());

  @override
  Object? key() => 'shared-counter-viewmodel';
}
