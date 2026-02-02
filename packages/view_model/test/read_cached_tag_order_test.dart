import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class SimpleVM extends ViewModel {
  final int id;
  SimpleVM(this.id);
}

class TestWidget extends StatelessWidget with ViewModelStatelessMixin {
  final int id;
  final String tag;
  final String keyV;

  TestWidget({
    super.key,
    required this.id,
    required this.tag,
    required this.keyV,
  });

  @override
  Widget build(BuildContext context) {
    viewModelBinding.watch(ViewModelSpec(
      builder: () => SimpleVM(id),
      tag: tag,
      key: keyV,
    ));
    return Container();
  }
}

void main() {
  testWidgets('readCached returns the latest instance for a given tag',
      (tester) async {
    ViewModel.initialize(config: ViewModelConfig(isLoggingEnabled: true));

    const tag = 'test_tag';

    // Create 3 instances with the same tag but different keys
    // Instance 1
    await tester.pumpWidget(MaterialApp(
      home: TestWidget(id: 1, tag: tag, keyV: 'vm1'),
    ));

    // Instance 2 (Latest)
    await tester.pumpWidget(MaterialApp(
      home: TestWidget(id: 2, tag: tag, keyV: 'vm2'),
    ));

    // Instance 3 (Latest)
    await tester.pumpWidget(MaterialApp(
      home: TestWidget(id: 3, tag: tag, keyV: 'vm3'),
    ));

    // Now readCached with tag should return vm3 (id: 3)
    final vm = ViewModel.readCached<SimpleVM>(tag: tag);

    expect(vm.id, 3);
  });
}
