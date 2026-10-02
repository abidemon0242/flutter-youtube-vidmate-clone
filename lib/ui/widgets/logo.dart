import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class TubeArenaLogo extends StatelessWidget {
  const TubeArenaLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.7,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size * 0.7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.18),
              gradient: const LinearGradient(
                colors: [AppColors.primaryStart, AppColors.primaryEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryStart.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.6,
            height: size * 0.4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.12),
              color: Colors.white,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.primaryEnd,
              size: 52,
            ),
          ),
          Positioned(
            bottom: size * 0.08,
            right: size * 0.12,
            child: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}
