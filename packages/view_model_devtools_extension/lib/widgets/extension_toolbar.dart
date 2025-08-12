import 'package:flutter/material.dart';

class ExtensionToolbar extends StatelessWidget implements PreferredSizeWidget {
  const ExtensionToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Row(
        children: [
          Icon(Icons.visibility),
          SizedBox(width: 8),
          Text('ViewModel Inspector'),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 1,
      actions: [],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
