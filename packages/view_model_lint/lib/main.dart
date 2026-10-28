import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules.dart';

final plugin = ViewModelLintPlugin();

class ViewModelLintPlugin extends Plugin {
  @override
  String get name => 'view_model_lint';

  @override
  void register(PluginRegistry registry) {
    for (final kind in ViewModelRuleKind.values) {
      if (kind.optIn) {
        registry.registerLintRule(ViewModelRule(kind));
      } else {
        registry.registerWarningRule(ViewModelRule(kind));
      }
    }
    for (final MapEntry(key: kind, value: fixes) in viewModelFixes.entries) {
      for (final fix in fixes) {
        registry.registerFixForRule(viewModelCode(kind), fix);
      }
    }
  }
}
