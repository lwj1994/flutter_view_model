// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '待办事项';

  @override
  String get addTodo => '添加待办';

  @override
  String get addTodoHint => '添加新的待办事项';

  @override
  String get categoryHint => '分类（可选）';

  @override
  String get noTodos => '暂无待办事项';

  @override
  String get editTodo => '编辑待办';

  @override
  String get editTodoTitle => '标题';

  @override
  String get editTodoCategory => '分类（可选）';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get clearCompleted => '清除已完成';

  @override
  String get searchTodos => '搜索待办事项';

  @override
  String get searchTodosHint => '搜索待办事项...';

  @override
  String get noMatchingTodos => '没有找到匹配的待办事项';

  @override
  String get todoStats => '待办事项统计';

  @override
  String get overview => '总览';

  @override
  String get total => '总数';

  @override
  String get completed => '已完成';

  @override
  String get remaining => '未完成';

  @override
  String get categoryStats => '分类统计';

  @override
  String get all => '全部';

  @override
  String totalTodos(int count) {
    return '总计: $count';
  }

  @override
  String completedTodos(int count) {
    return '已完成: $count';
  }

  @override
  String incompleteTodos(int count) {
    return '未完成: $count';
  }
}
