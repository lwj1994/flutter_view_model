import 'package:flutter/material.dart';

import '../widgets/extension_toolbar.dart';
import '../widgets/view_model_inspector.dart';

class ExtensionMain extends StatefulWidget {
  const ExtensionMain({super.key});

  @override
  State<ExtensionMain> createState() => _ExtensionMainState();
}

class _ExtensionMainState extends State<ExtensionMain> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: ExtensionToolbar(),
      body: ViewModelInspector(),
    );
  }
}
