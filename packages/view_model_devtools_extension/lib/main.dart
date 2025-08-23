import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/extension_main.dart';

void main() {
  runApp(const ViewModelDevToolsExtension());
}

class ViewModelDevToolsExtension extends StatelessWidget {
  const ViewModelDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: ExtensionMain(),
    );
  }
}
