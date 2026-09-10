import 'package:flutter/material.dart';

/// DOSS brand logo widgets — backed by the official transparent PNG assets.
/// Public API preserved (DossLogo, DossHeroLogo + params) so all existing
/// call sites across doss_driver and doss_rider keep working.

class DossLogo extends StatelessWidget {
  /// Height of the logo. Headers pass a size; the full DOSS logo
  /// (mark + wordmark) is shown so the brand name is always visible.
  final double size;
  const DossLogo({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/doss_logo.png', // full logo: speed-D + "DOSS"
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class DossHeroLogo extends StatelessWidget {
  final double iconSize;
  final bool showTagline;
  const DossHeroLogo({
    super.key,
    this.iconSize = 80,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/doss_logo.png',
          height: iconSize * 2.2,
          fit: BoxFit.contain,
        ),
        if (showTagline) ...[
          const SizedBox(height: 16),
          const Text(
            'تنقّل بذكاء • حياة أسهل',
            style: TextStyle(
              color: Color(0xFFA8B3BD),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
