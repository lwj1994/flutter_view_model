import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

/// 1. Define the ViewModel
class CounterViewModel with ViewModel {
  int count = 0;

  void increment() {
    update(() => count++);
  }
}

/// 2. Define the Spec
final counterSpec = ViewModelSpec<CounterViewModel>(
  builder: () => CounterViewModel(),
);

/// 3. Use in a Widget
class CounterWidget extends StatefulWidget {
  const CounterWidget({super.key});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget>
    with ViewModelStateMixin {
  // Bind and watch the ViewModel
  late final vm = viewModelBinding.watch(counterSpec);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: ${vm.count}'),
        ElevatedButton(
          onPressed: vm.increment,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
