import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class CNVM extends ChangeNotifierViewModel {
  void bump() => notifyListeners();
}

void main() {
  group('ChangeNotifierViewModel', () {
    test('addListener forwards to ViewModel.listen', () {
      final vm = CNVM();
      int hit = 0;
      vm.addListener(() => hit++);
      vm.bump();
      expect(hit, 1);
    });
  });
}
