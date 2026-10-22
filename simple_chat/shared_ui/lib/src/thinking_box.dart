import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'animated_ellipsis.dart';

/// Collects the agent's thinking as it streams in.
///
/// A [ThinkingBox] listens to this, so chunks can be added from wherever the
/// stream is read without holding on to any widget.
class ThinkingBoxController extends ChangeNotifier {
  ThinkingBoxController();

  bool _isVisible = false;

  /// Whether the box shows at all.
  ///
  /// Turn this on when a turn starts, before any thought has arrived: the box
  /// shows just the ellipsis until the first chunk lands. Turn it off when the
  /// turn ends.
  bool get isVisible => _isVisible;

  set isVisible(bool value) {
    if (_isVisible == value) return;
    _isVisible = value;
    notifyListeners();
  }

  bool _isPaused = false;

  /// Whether the turn is paused.
  ///
  /// A paused box stays on screen with its thought, and hides its ellipsis
  /// until the turn resumes.
  bool get isPaused => _isPaused;

  set isPaused(bool value) {
    if (_isPaused == value) return;
    _isPaused = value;
    notifyListeners();
  }

  final StringBuffer _thought = StringBuffer();

  /// Everything added since the last [clear].
  String get text => _thought.toString();

  /// Whether no thought has been collected yet.
  ///
  /// Independent of [isVisible]: a visible box with nothing collected shows
  /// the ellipsis on its own.
  bool get isEmpty => _thought.isEmpty;

  /// Appends [mdChunk] to the thought process.
  void addChunk(String mdChunk) {
    if (mdChunk.isEmpty) return;
    _thought.write(mdChunk);
    notifyListeners();
  }

  /// Drops the thought collected so far.
  ///
  /// Leaves [isVisible] alone, so clearing mid-turn falls back to the
  /// ellipsis rather than hiding the box.
  void clear() {
    if (_thought.isEmpty) return;
    _thought.clear();
    notifyListeners();
  }
}

/// A card that displays tail of thought process in markdown.
///
/// When [ThinkingBoxController.isVisible] is false, nothing is shown. When it
/// is true, shows tail of the collected thought and an animated ellipsis, or
/// just the ellipsis while no thought has arrived yet.
class ThinkingBox extends StatefulWidget {
  const ThinkingBox({super.key, required this.controller});

  final ThinkingBoxController controller;

  /// The box stops growing here and older thought scrolls off the top, so a
  /// long ramble cannot push the conversation off screen.
  static const double _maxHeight = 120.0;

  @override
  State<ThinkingBox> createState() => _ThinkingBoxState();
}

class _ThinkingBoxState extends State<ThinkingBox> {
  final ScrollController _scrollController = ScrollController();

  /// Whether new thought should pull the view down with it.
  ///
  /// Scrolling up turns this off, so reading back through the thought is not
  /// yanked to the bottom by every chunk that lands. Scrolling back to the
  /// bottom turns it on again.
  bool _followTail = true;

  /// Scroll metrics land a fraction of a pixel short of the end often enough
  /// that 'at the bottom' has to be a range rather than an exact match.
  static const double _tailTolerance = 8.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Pins the view to the newest thought, which is what makes the box show the
  /// tail rather than the beginning.
  ///
  /// Does nothing once the reader has scrolled away from the end.
  void _scrollToEnd() {
    if (!_followTail) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_followTail || !_scrollController.hasClients) return;
      final ScrollPosition position = _scrollController.position;
      if (position.pixels != position.maxScrollExtent) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (!widget.controller.isVisible) return const SizedBox.shrink();

        final ThemeData theme = Theme.of(context);
        final TextStyle? style = theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
        final String thought = widget.controller.text;

        if (thought.isEmpty) {
          // Nothing left to read back through, so the next thought to arrive
          // should pull the view along again.
          _followTail = true;
        } else {
          _scrollToEnd();
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nothing collected yet leaves the ellipsis on its own, rather
                // than an empty band above it.
                if (thought.isNotEmpty)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: ThinkingBox._maxHeight,
                      ),
                      // Fires for scrolls, not for content growing, so a
                      // chunk landing cannot switch following off by itself.
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          final ScrollMetrics metrics = notification.metrics;
                          _followTail =
                              metrics.pixels >=
                              metrics.maxScrollExtent - _tailTolerance;
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: MarkdownBody(
                            data: thought,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(p: style),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Kept outside the scroll view so it stays visible while the
                // thought above it scrolls.
                if (!widget.controller.isPaused)
                  const Align(
                    alignment: Alignment.center,
                    child: AnimatedEllipsis(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
