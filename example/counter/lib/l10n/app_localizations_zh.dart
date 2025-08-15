// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '计数器示例';

  @override
  String get currentCount => '当前计数：';

  @override
  String incrementBy(int value) {
    return '每次增加/减少：$value';
  }

  @override
  String get decrease => '减少';

  @override
  String get increase => '增加';

  @override
  String get reset => '重置';

  @override
  String get settings => '设置';

  @override
  String get settingsTitle => '计数器设置';

  @override
  String get incrementSetting => '增量设置';

  @override
  String get adjustIncrementHint => '调整每次增加或减少的数值：';

  @override
  String get settingsDescription =>
      '• 增量值决定了每次点击增加或减少按钮时的变化量\n• 增量值的范围是1到10\n• 修改后的增量值会立即生效，并在主页面显示';
}
