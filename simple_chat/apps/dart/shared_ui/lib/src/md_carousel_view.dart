import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final Logger _logger = Logger('MdCarouselView');

/// Opens [href] with the platform's default handler.
///
/// A link that cannot be parsed or opened is logged and dropped: tapping a
/// broken link in a generated card should do nothing, not tear down the
/// surface it sits on.
Future<void> _openLink(String? href) async {
  if (href == null || href.isEmpty) return;

  final Uri? url = Uri.tryParse(href);
  if (url == null) {
    _logger.warning('Ignoring a markdown link that is not a URL: $href');
    return;
  }

  try {
    if (!await launchUrl(url)) {
      _logger.warning('Could not open $url.');
    }
  } catch (exception, stackTrace) {
    _logger.warning('Could not open $url.', exception, stackTrace);
  }
}

/// A horizontally scrolling list of markdown texts, each with a 'Select'
/// button.
///
/// Arrow buttons overlay the left and right edges. Each one appears only while
/// there is more to scroll in its direction, so on a list that fits entirely
/// on screen neither is shown.
class MdCarouselView extends StatefulWidget {
  const MdCarouselView({super.key, required this.items, this.onSelect});

  /// The cards to show: each key is the name shown at the top of a card, each
  /// value is the markdown rendered below it. Iteration order is the order the
  /// cards appear in, so pass a map that preserves insertion order (the
  /// default for map literals).
  ///
  /// Names double as the identity of a card, so two cards cannot share one.
  final Map<String, String> items;

  /// Called with the name and value of the card whose 'Select' button the user
  /// pressed.
  final void Function(String title, String value)? onSelect;

  /// Tall enough for a few lines of markdown above the button.
  static const double _carouselHeight = 280.0;

  /// Narrow enough that the next card peeks in and hints at the scrolling.
  static const double _cardWidth = 260.0;

  static const double _cardSpacing = 12.0;

  @override
  State<MdCarouselView> createState() => _MdCarouselViewState();
}

class _MdCarouselViewState extends State<MdCarouselView> {
  final ScrollController _controller = ScrollController();

  bool _canScrollBack = false;
  bool _canScrollForward = false;

  /// One arrow press moves by a whole card, so cards stay roughly aligned
  /// with the edges instead of drifting out of step.
  static const double _scrollStep =
      MdCarouselView._cardWidth + MdCarouselView._cardSpacing;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncArrows);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Recomputes which arrows apply, once the current frame is done.
  ///
  /// Metrics change outside of scrolling too — when the window is resized or
  /// the page zoomed — and those notifications arrive mid-layout, where
  /// `setState` is not allowed. Deferring by a frame covers both.
  void _syncArrowsAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  /// Recomputes which arrows apply.
  void _syncArrows() {
    if (!mounted || !_controller.hasClients) return;
    final ScrollPosition position = _controller.position;
    final bool back = position.extentBefore > 0;
    final bool forward = position.extentAfter > 0;
    // Guarded so the post-frame call settles after one frame rather than
    // scheduling a rebuild forever.
    if (back == _canScrollBack && forward == _canScrollForward) return;
    setState(() {
      _canScrollBack = back;
      _canScrollForward = forward;
    });
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final ScrollPosition position = _controller.position;
    _controller.animateTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    // `items.keys` and `items.values` are lazy iterables with no `[]`, so the
    // entries are materialized once instead of walked per card.
    final List<MapEntry<String, String>> entries = widget.items.entries
        .toList();

    _syncArrowsAfterFrame();

    return SizedBox(
      height: MdCarouselView._carouselHeight,
      child: Stack(
        children: [
          // The viewport can change size without anything scrolling — a window
          // resize, or the browser zooming — and that is the only signal for
          // it, so the arrows would otherwise keep whatever state they had.
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _syncArrowsAfterFrame();
              return false;
            },
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              itemCount: entries.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: MdCarouselView._cardSpacing),
              itemBuilder: (context, index) {
                final MapEntry<String, String> entry = entries[index];
                return SizedBox(
                  width: MdCarouselView._cardWidth,
                  child: _MdCarouselCard(
                    name: entry.key,
                    markdown: entry.value,
                    onSelect: widget.onSelect == null
                        ? null
                        : () => widget.onSelect!(entry.key, entry.value),
                  ),
                );
              },
            ),
          ),
          _ScrollArrow(
            alignment: Alignment.centerLeft,
            icon: Icons.chevron_left,
            tooltip: 'Scroll left',
            visible: _canScrollBack,
            onPressed: () => _scrollBy(-_scrollStep),
          ),
          _ScrollArrow(
            alignment: Alignment.centerRight,
            icon: Icons.chevron_right,
            tooltip: 'Scroll right',
            visible: _canScrollForward,
            onPressed: () => _scrollBy(_scrollStep),
          ),
        ],
      ),
    );
  }
}

/// One of the two arrows overlaying a [MdCarouselView].
///
/// It fades out rather than leaving the tree, so the cards underneath do not
/// shift when the carousel reaches an end.
class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.visible,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          // A faded-out arrow is still hit-testable, so taps have to be
          // blocked explicitly or it would scroll an already-ended list.
          child: IgnorePointer(
            ignoring: !visible,
            child: IconButton.filledTonal(
              tooltip: tooltip,
              icon: Icon(icon),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

/// A single card in a [MdCarouselView].
class _MdCarouselCard extends StatelessWidget {
  const _MdCarouselCard({
    required this.name,
    required this.markdown,
    this.onSelect,
  });

  /// Shown at the top of the card, above the markdown.
  final String name;

  final String markdown;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        // Makes the name and the markdown selectable without replacing either
        // with a `SelectableText`, which has no `overflow` and so would cost
        // the name its ellipsis, and without `MarkdownBody.selectable`, which
        // takes over the gestures that `onTapLink` needs.
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // The card has a fixed height and the markdown can be any
              // length, so it scrolls rather than overflowing. `MarkdownBody`
              // is the non-scrolling variant, which is what makes it
              // embeddable here.
              Expanded(
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: markdown,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme),
                    onTapLink: (text, href, title) => _openLink(href),
                  ),
                ),
              ),
              if (onSelect != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  // Kept out of the selection: dragging across the card should
                  // pick up its text, not the button's label.
                  child: SelectionContainer.disabled(
                    child: FilledButton(
                      onPressed: onSelect,
                      child: const Text('Select'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
