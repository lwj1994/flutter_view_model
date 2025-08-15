import 'package:flutter/material.dart';
import 'package:view_model/view_model.dart';

import 'counter_view_model.dart';
import 'l10n/app_localizations.dart';
import 'settings_page.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage>
    with ViewModelStateMixin<CounterPage> {
  CounterViewModel get counterVM =>
      watchViewModel<CounterViewModel>(factory: CounterViewModelFactory());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            tooltip: l10n.settings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.currentCount,
              style: const TextStyle(fontSize: 20),
            ),
            Text(
              '${counterVM.state.count}',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.incrementBy(counterVM.state.incrementBy),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: counterVM.decrement,
                  icon: const Icon(Icons.remove),
                  label: Text(l10n.decrease),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: counterVM.increment,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.increase),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: counterVM.reset,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.reset),
            ),
          ],
        ),
      ),
    );
  }
}
