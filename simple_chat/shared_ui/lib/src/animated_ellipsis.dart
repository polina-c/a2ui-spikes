import 'package:flutter/material.dart';

/// A '.', '..', '...' cycle, showing that more is still coming.
class AnimatedEllipsis extends StatefulWidget {
  const AnimatedEllipsis({super.key, this.style});

  /// Defaults to heavy, widely spaced [TextTheme.headlineLarge] in the muted
  /// text color, big enough to notice beside body text.
  final TextStyle? style;

  /// One full cycle of the ellipsis.
  static const Duration period = Duration(milliseconds: 1200);

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
    final ThemeData theme = Theme.of(context);
    final TextStyle? style =
        widget.style ??
        theme.textTheme.headlineLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          height: 0.8,
        );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final int dots = 1 + (_animation.value * 3).floor().clamp(0, 2);
        // Padded to a constant width so the line does not twitch as the dot
        // count changes.
        return Text('.' * dots + ' ' * (3 - dots), style: style);
      },
    );
  }
}
