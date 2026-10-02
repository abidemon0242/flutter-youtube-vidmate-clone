import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class TubeArenaTopBar extends StatelessWidget implements PreferredSizeWidget {
  const TubeArenaTopBar({super.key, this.onSearchTap, this.onMenuTap});

  final VoidCallback? onSearchTap;
  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.menu, color: AppColors.white),
          const SizedBox(width: 12),
          const Text(
            'Tube Arena',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onSearchTap,
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }
}
