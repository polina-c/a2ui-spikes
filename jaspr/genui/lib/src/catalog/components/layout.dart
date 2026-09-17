import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../catalog_item.dart';
import '../schemas.dart';

/// Arranges children vertically.
final CatalogItem columnItem = _flexItem(
  name: 'Column',
  description: 'Arranges its children in a vertical column.',
  direction: 'column',
);

/// Arranges children horizontally.
final CatalogItem rowItem = _flexItem(
  name: 'Row',
  description: 'Arranges its children in a horizontal row.',
  direction: 'row',
);

/// A scrollable list of children.
final CatalogItem listItem = CatalogItem(
  name: 'List',
  schema: Schema.object(
    description: 'A scrollable list of children.',
    properties: {
      'children': A2uiSchemas.children(),
      'direction': Schema.string(enumValues: ['vertical', 'horizontal']),
      'align': Schema.string(enumValues: ['start', 'center', 'end', 'stretch']),
    },
    required: ['children'],
  ),
  builder: (context) {
    final String direction = context.string('direction') ?? 'vertical';
    return DomComponent(
      tag: 'div',
      attributes: {
        'class': 'a2ui-list a2ui-list-$direction',
        'style':
            'display:flex;overflow:auto;'
            'flex-direction:${direction == 'horizontal' ? 'row' : 'column'};'
            'align-items:${_align(context.string('align'))}',
      },
      children: [
        for (final core.ChildNode child in context.children('children'))
          context.buildChild(child),
      ],
    );
  },
);

/// A container that visually groups one child.
final CatalogItem cardItem = CatalogItem(
  name: 'Card',
  schema: Schema.object(
    description: 'A container that visually groups a single child.',
    properties: {'child': A2uiSchemas.componentId()},
    required: ['child'],
  ),
  builder: (context) => DomComponent(
    tag: 'div',
    attributes: const {'class': 'a2ui-card'},
    children: [context.buildChild(context['child'])],
  ),
);

/// A rule separating content.
final CatalogItem dividerItem = CatalogItem(
  name: 'Divider',
  schema: Schema.object(
    description: 'A thin line separating content.',
    properties: {
      'axis': Schema.string(enumValues: ['horizontal', 'vertical']),
    },
  ),
  builder: (context) {
    final String axis = context.string('axis') ?? 'horizontal';
    return DomComponent(
      tag: axis == 'vertical' ? 'div' : 'hr',
      attributes: {'class': 'a2ui-divider a2ui-divider-$axis'},
      children: const [],
    );
  },
);

CatalogItem _flexItem({
  required String name,
  required String description,
  required String direction,
}) {
  return CatalogItem(
    name: name,
    schema: Schema.object(
      description: description,
      properties: {
        'children': A2uiSchemas.children(),
        'justify': Schema.string(
          description: 'How children are distributed along the $direction.',
          enumValues: [
            'start',
            'center',
            'end',
            'spaceBetween',
            'spaceAround',
            'spaceEvenly',
            'stretch',
          ],
        ),
        'align': Schema.string(
          description: 'How children line up across the $direction.',
          enumValues: ['start', 'center', 'end', 'stretch'],
        ),
      },
      required: ['children'],
    ),
    builder: (context) => DomComponent(
      tag: 'div',
      attributes: {
        'class': 'a2ui-$direction',
        'style':
            'display:flex;flex-direction:$direction;'
            'justify-content:${_justify(context.string('justify'))};'
            'align-items:${_align(context.string('align'))}',
      },
      children: [
        for (final core.ChildNode child in context.children('children'))
          context.buildChild(child),
      ],
    ),
  );
}

String _justify(String? value) => switch (value) {
  'center' => 'center',
  'end' => 'flex-end',
  'spaceBetween' => 'space-between',
  'spaceAround' => 'space-around',
  'spaceEvenly' => 'space-evenly',
  _ => 'flex-start',
};

String _align(String? value) => switch (value) {
  'center' => 'center',
  'end' => 'flex-end',
  'start' => 'flex-start',
  _ => 'stretch',
};
