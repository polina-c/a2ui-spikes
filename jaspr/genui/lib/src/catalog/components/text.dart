import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../catalog_item.dart';
import '../markdown.dart';
import '../schemas.dart';

/// A block of text, optionally styled as a heading or caption.
final CatalogItem textItem = CatalogItem(
  name: 'Text',
  schema: Schema.object(
    description: 'A block of text.',
    properties: {
      'text': A2uiSchemas.string(
        description:
            'The text to show. Simple inline Markdown is supported: '
            '**bold**, *italic*, `code` and [label](url). For anything '
            'richer, prefer dedicated components.',
      ),
      'variant': Schema.string(
        description: 'How prominent the text is.',
        enumValues: ['h1', 'h2', 'h3', 'h4', 'h5', 'caption', 'body'],
      ),
    },
    required: ['text'],
  ),
  builder: (context) {
    final String variant = context.string('variant') ?? 'body';
    final String value = context.string('text') ?? '';
    final String tag = switch (variant) {
      'h1' => 'h1',
      'h2' => 'h2',
      'h3' => 'h3',
      'h4' => 'h4',
      'h5' => 'h5',
      _ => 'p',
    };
    return DomComponent(
      tag: tag,
      attributes: {'class': 'a2ui-text a2ui-text-$variant'},
      children: renderInlineMarkdown(value),
    );
  },
);
