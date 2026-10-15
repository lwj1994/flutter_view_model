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
      registry.registerWarningRule(ViewModelRule(kind));
    }
  }
}
