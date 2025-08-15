// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Todo List';

  @override
  String get addTodo => 'Add Todo';

  @override
  String get addTodoHint => 'Add new todo';

  @override
  String get categoryHint => 'Category (optional)';

  @override
  String get noTodos => 'No todos yet';

  @override
  String get editTodo => 'Edit Todo';

  @override
  String get editTodoTitle => 'Title';

  @override
  String get editTodoCategory => 'Category (optional)';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearCompleted => 'Clear completed';

  @override
  String get searchTodos => 'Search Todos';

  @override
  String get searchTodosHint => 'Search todos...';

  @override
  String get noMatchingTodos => 'No matching todos found';

  @override
  String get todoStats => 'Todo Statistics';

  @override
  String get overview => 'Overview';

  @override
  String get total => 'Total';

  @override
  String get completed => 'Completed';

  @override
  String get remaining => 'Remaining';

  @override
  String get categoryStats => 'Category Statistics';

  @override
  String get all => 'All';

  @override
  String totalTodos(int count) {
    return 'Total todos: $count';
  }

  @override
  String completedTodos(int count) {
    return 'Completed: $count';
  }

  @override
  String incompleteTodos(int count) {
    return 'Incomplete: $count';
  }
}
