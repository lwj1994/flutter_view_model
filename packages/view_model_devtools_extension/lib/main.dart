import 'package:devtools_extensions/devtools_extensions.dart';
// Flutter 3.50 deprecates this library for package:material_ui, a separate
// copy whose types do not mix with the SDK's; migrate when dependencies do.
// ignore: deprecated_member_use
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
