import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Interactive 5-star rating selector
class RatingWidget extends StatefulWidget {
  final int initialRating;
  final double starSize;
  final bool readOnly;
  final ValueChanged<int> onRatingChanged;

  const RatingWidget({
    super.key,
    this.initialRating = 0,
    this.starSize = 36,
    this.readOnly = false,
    required this.onRatingChanged,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < _rating;
          return GestureDetector(
            onTap: widget.readOnly
                ? null
                : () {
                    setState(() => _rating = i + 1);
                    widget.onRatingChanged(i + 1);
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey('$i-$filled'),
                  color: filled ? const Color(0xFFFFC107) : AppTheme.textMuted,
                  size: widget.starSize,
                ),
              ),
            ),
          );
        }),
      );
}

/// Read-only inline star + number display
class StarRating extends StatelessWidget {
  final double rating;
  final double size;

  const StarRating({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: const Color(0xFFFFC107), size: size),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: size * 0.9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
}
