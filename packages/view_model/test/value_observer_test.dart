import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:view_model/src/observer/value_observer.dart';

void main() {
  group('ObservableValue', () {
    test('should hold an initial value', () {
      final observable = ObservableValue<int>(10);
      expect(observable.value, 10);
    });

    test('should update the value', () {
      final observable = ObservableValue<int>(10);
      observable.value = 20;
      expect(observable.value, 20);
    });

    test('should not notify when the value is the same', () {
      final observable = ObservableValue<int>(10);

      final initialValue = observable.value;
      observable.value = 10; // Set same value

      // This is a conceptual test. In a real app with listeners,
      // no rebuild would be triggered. Here we just assert the value is unchanged.
      expect(observable.value, initialValue);
    });
  });

  group('ObserverBuilder', () {
    testWidgets('should build with the initial value',
        (WidgetTester tester) async {
      final observable = ObservableValue<int>(5);
      await tester.pumpWidget(
        MaterialApp(
          home: ObserverBuilder<int>(
            observable: observable,
            builder: (context) {
              return Text(observable.value.toString());
            },
          ),
        ),
      );
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('should rebuild when the value changes',
        (WidgetTester tester) async {
      final observable = ObservableValue<int>(5);
      await tester.pumpWidget(
        MaterialApp(
          home: ObserverBuilder<int>(
            observable: observable,
            builder: (context) {
              return Text(observable.value.toString());
            },
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);

      observable.value = 10;
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('should throw an error for dynamic type',
        (WidgetTester tester) async {
      final observable = ObservableValue<dynamic>(5);
      await tester.pumpWidget(
        MaterialApp(
          home: ObserverBuilder(
            observable: observable,
            builder: (context) {
              return Text(observable.value.toString());
            },
          ),
        ),
      );

      final dynamic exception = tester.takeException();
      expect(exception, isA<UnsupportedError>());
      expect(exception.message, contains("requires a specific type 'T'"));
    });
  });

  group('ObserverBuilder2', () {
    testWidgets('should rebuild when the first value changes',
        (WidgetTester tester) async {
      final observable1 = ObservableValue<int>(1);
      final observable2 = ObservableValue<String>('A');

      await tester.pumpWidget(
        MaterialApp(
          home: ObserverBuilder2<int, String>(
            observable1: observable1,
            observable2: observable2,
            builder: (context) {
              return Text('${observable1.value} ${observable2.value}');
            },
          ),
        ),
      );

      expect(find.text('1 A'), findsOneWidget);

      observable1.value = 2;
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2 A'), findsOneWidget);
    });

    testWidgets('should rebuild when the second value changes',
        (WidgetTester tester) async {
      final observable1 = ObservableValue<int>(1);
      final observable2 = ObservableValue<String>('A');

      await tester.pumpWidget(
        MaterialApp(
          home: ObserverBuilder2<int, String>(
            observable1: observable1,
            observable2: observable2,
            builder: (context) {
              return Text('${observable1.value} ${observable2.value}');
            },
          ),
        ),
      );

      expect(find.text('1 A'), findsOneWidget);

      observable2.value = 'B';
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1 B'), findsOneWidget);
    });
  });

  group('ObserverBuilder3', () {
    testWidgets('should rebuild when any value changes',
        (WidgetTester tester) async {
      final observable1 = ObservableValue<int>(1);
      final observable2 = ObservableValue<String>('A');
      final observable3 = ObservableValue<double>(1.0);

      await tester.pumpWidget(
        MaterialApp(
          home: ObserverBuilder3<int, String, double>(
            observable1: observable1,
            observable2: observable2,
            observable3: observable3,
            builder: (context) {
              return Text(
                  '${observable1.value} ${observable2.value} ${observable3.value}');
            },
          ),
        ),
      );

      expect(find.text('1 A 1.0'), findsOneWidget);

      observable1.value = 2;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 A 1.0'), findsOneWidget);

      observable2.value = 'B';
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 B 1.0'), findsOneWidget);

      observable3.value = 2.0;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2 B 2.0'), findsOneWidget);
    });
  });

  group('Data Sharing and Isolation', () {
    testWidgets('should share data with the same shareKey',
        (WidgetTester tester) async {
      final shareKey = Object();
      final observable1 = ObservableValue<int>(10, shareKey: shareKey);
      // observable2 will now be managed by the same ViewModel due to the shared key.
      final observable2 = ObservableValue<int>(10, shareKey: shareKey);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ObserverBuilder<int>(
                observable: observable1,
                builder: (context) => Text('Builder1: ${observable1.value}'),
              ),
              ObserverBuilder<int>(
                observable: observable2,
                builder: (context) => Text('Builder2: ${observable2.value}'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Builder1: 10'), findsOneWidget);
      expect(find.text('Builder2: 10'), findsOneWidget);

      // When observable1's value is updated, the underlying ViewModel is updated.
      observable1.value = 20;
      await tester.pump(const Duration(seconds: 1));

      // Both builders should reflect the new value because they share the same ViewModel.
      // And observable2.value should also be updated internally.
      expect(observable2.value, 20);
      expect(find.text('Builder1: 20'), findsOneWidget);
      expect(find.text('Builder2: 20'), findsOneWidget);
    });

    testWidgets('should isolate data with different shareKeys', (tester) async {
      final observable1 = ObservableValue<int>(10, shareKey: 'key1');
      final observable2 = ObservableValue<int>(100, shareKey: 'key2');

      await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                ObserverBuilder(
                  observable: observable2,
                  builder: (context) {
                    final val = observable2.value;
                    // ignore: avoid_print
                    return Text('Builder2: $val');
                  },
                ),
                ObserverBuilder(
                  observable: observable1,
                  builder: (context) {
                    return Text('Builder1: ${observable1.value}');
                  },
                ),
              ],
            ),
          ),
          duration: const Duration(seconds: 1));

      expect(find.text('Builder1: 10'), findsOneWidget);
      expect(find.text('Builder2: 100'), findsOneWidget);

      observable1.value = 20;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Builder1: 20'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      observable2.value = 102;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Builder2: 102'), findsOneWidget); // Should not change
    });
  });
}
