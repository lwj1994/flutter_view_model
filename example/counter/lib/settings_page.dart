import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import 'counter_view_model.dart';
import 'l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with ViewModelStateMixin<SettingsPage> {
  CounterViewModel get counterVM =>
      vef.watchCached<CounterViewModel>(key: 'shared-counter-viewmodel');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.incrementSetting,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adjustIncrementHint,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: counterVM.state.incrementBy.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: counterVM.state.incrementBy.toString(),
                    onChanged: (value) {
                      counterVM.setIncrementBy(value.toInt());
                    },
                  ),
                ),
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text(
                    '${counterVM.state.incrementBy}',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              l10n.settingsDescription,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
