// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Counter Example';

  @override
  String get currentCount => 'Current Count:';

  @override
  String incrementBy(int value) {
    return 'Increment By: $value';
  }

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get reset => 'Reset';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Counter Settings';

  @override
  String get incrementSetting => 'Increment Setting';

  @override
  String get adjustIncrementHint =>
      'Adjust the value to increase or decrease by:';

  @override
  String get settingsDescription =>
      '• The increment value determines how much the counter changes each time\n• The range is from 1 to 10\n• Changes take effect immediately and are shown on the main page';
}
