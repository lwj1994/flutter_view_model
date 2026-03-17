import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_list/main.dart' as app;
import 'package:todo_list/todo_view_model.dart';

void main() {
  testWidgets('adds a todo item with an optional category',
      (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'Buy milk');
    await tester.enterText(find.byType(TextField).at(1), 'Groceries');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  test('editing a todo can clear its category', () {
    final viewModel = TodoViewModel();
    viewModel.addTodo('Buy milk', category: 'Groceries');

    final todo = viewModel.state.items.single;
    expect(todo.category, 'Groceries');

    viewModel.editTodo(todo.id, 'Buy milk', newCategory: null);

    expect(viewModel.state.items.single.category, isNull);
  });
}
