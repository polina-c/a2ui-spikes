import 'package:jaspr/jaspr.dart';

/// Renders the inline Markdown subset that generated `Text` uses.
///
/// Supports `**bold**`, `*italic*`, `` `code` `` and `[label](url)`. The
/// output is a list of Jaspr nodes, never a string of HTML: a model's output
/// is untrusted input, and building nodes means markup in it can only ever
/// be text. Link targets are restricted to http and https for the same
/// reason, so a generated `javascript:` URL cannot become a live link.
List<Component> renderInlineMarkdown(String source) {
  final components = <Component>[];
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) return;
    components.add(Component.text(buffer.toString()));
    buffer.clear();
  }

  var i = 0;
  while (i < source.length) {
    final String rest = source.substring(i);

    final RegExpMatch? match = _inline.matchAsPrefix(rest) as RegExpMatch?;
    if (match == null) {
      buffer.write(source[i]);
      i += 1;
      continue;
    }

    flush();
    if (match.namedGroup('bold') != null) {
      components.add(
        DomComponent(
          tag: 'strong',
          children: renderInlineMarkdown(match.namedGroup('bold')!),
        ),
      );
    } else if (match.namedGroup('italic') != null) {
      components.add(
        DomComponent(
          tag: 'em',
          children: renderInlineMarkdown(match.namedGroup('italic')!),
        ),
      );
    } else if (match.namedGroup('code') != null) {
      components.add(
        DomComponent(
          tag: 'code',
          children: [Component.text(match.namedGroup('code')!)],
        ),
      );
    } else {
      final String label = match.namedGroup('label')!;
      final String? href = _safeHref(match.namedGroup('href')!);
      components.add(
        href == null
            ? Component.text(label)
            : DomComponent(
                tag: 'a',
                attributes: {
                  'href': href,
                  'target': '_blank',
                  'rel': 'noopener noreferrer',
                },
                children: [Component.text(label)],
              ),
      );
    }
    i += match.end;
  }

  flush();
  return components;
}

final RegExp _inline = RegExp(
  r'\*\*(?<bold>[^*]+)\*\*'
  r'|\*(?<italic>[^*]+)\*'
  r'|`(?<code>[^`]+)`'
  r'|\[(?<label>[^\]]*)\]\((?<href>[^)\s]+)\)',
);

String? _safeHref(String href) {
  final Uri? uri = Uri.tryParse(href.trim());
  if (uri == null) return null;
  if (uri.scheme == 'http' || uri.scheme == 'https') return uri.toString();
  // A relative link stays within the app, so it carries no scheme risk.
  if (!uri.hasScheme && !href.trim().startsWith('//')) return uri.toString();
  return null;
}
