import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/view_model.dart';

class _FactoryCompatViewModel extends ViewModel {}

class _DefaultFactory with ViewModelFactory<_FactoryCompatViewModel> {
  @override
  _FactoryCompatViewModel build() => _FactoryCompatViewModel();
}

class _LegacySingletonFactory with ViewModelFactory<_FactoryCompatViewModel> {
  @override
  _FactoryCompatViewModel build() => _FactoryCompatViewModel();

  @override
  bool singleton() => true;
}

void main() {
  group('ViewModelFactory compatibility', () {
    test('default key is null', () {
      expect(_DefaultFactory().key(), isNull);
    });

    test('singleton() provides shared default key', () {
      final first = _LegacySingletonFactory();
      final second = _LegacySingletonFactory();

      final firstKey = first.key();
      final secondKey = second.key();

      expect(firstKey, isNotNull);
      expect(identical(firstKey, secondKey), isTrue);
    });
  });
}
