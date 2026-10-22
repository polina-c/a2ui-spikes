import 'package:flutter/material.dart';

/// Dots that cycle from one to three, showing that more is still coming.
///
/// Drawn as circles rather than text, because a period is a small glyph even
/// in a large font.
class AnimatedEllipsis extends StatefulWidget {
  const AnimatedEllipsis({super.key, this.dotSize = 10.0, this.color});

  /// The diameter of each dot.
  final double dotSize;

  /// Defaults to the muted text color of the theme.
  final Color? color;

  /// One full cycle of the ellipsis.
  static const Duration period = Duration(milliseconds: 1200);

  static const int _maxDots = 3;

  @override
  State<AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: AnimatedEllipsis.period,
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        const int max = AnimatedEllipsis._maxDots;
        final int dots = 1 + (_animation.value * max).floor().clamp(0, max - 1);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < max; i++)
              // Hidden dots keep their space, so the row does not twitch as
              // the count changes.
              Opacity(
                opacity: i < dots ? 1.0 : 0.0,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  margin: EdgeInsets.all(widget.dotSize / 3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
