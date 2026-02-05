import 'package:flutter/material.dart';

class ExtensionToolbar extends StatelessWidget implements PreferredSizeWidget {
  static const int _iconBgAlpha = 30;

  const ExtensionToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: _ToolbarTitle(iconBgAlpha: _iconBgAlpha),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ToolbarTitle extends StatelessWidget {
  final int iconBgAlpha;

  const _ToolbarTitle({required this.iconBgAlpha});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primary.withAlpha(iconBgAlpha),
          child: Icon(
            Icons.hub_outlined,
            color: theme.colorScheme.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ViewModel DevTools',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Binding ↔ VM Graph',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
