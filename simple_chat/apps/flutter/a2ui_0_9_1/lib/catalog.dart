import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:a2ui_flutter/basic_catalog.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:shared_ui/shared_ui.dart';

/// Where the shared A2UI types are defined, for the schemas of this catalog.
class _Refs {
  static const String commonTypes =
      'https://a2ui.org/specification/v0_9/common_types.json#/\$defs';
  static const String componentCommon = '$commonTypes/ComponentCommon';
  static const String action = '$commonTypes/Action';
  static const String catalogComponentCommon =
      '#/\$defs/CatalogComponentCommon';
}

/// The components the model builds the chat's UI from.
///
/// From the basic catalog, it keeps what a question with likely answers, or a
/// recommendation card with a link, needs. It adds [mdCarousel], to show
/// options side by side.
CatalogImplementation chatCatalog() {
  final CatalogApi basic = BasicComponents.api;
  return CatalogImplementation(
    id: 'https://github.com/polina-c/a2ui-spikes/simple_chat/catalog.json',
    components: [
      BasicComponents.text,
      BasicComponents.image,
      BasicComponents.row,
      BasicComponents.column,
      BasicComponents.card,
      BasicComponents.divider,
      BasicComponents.button,
      mdCarousel,
    ],
    functions: [
      BasicCatalog.v0_9(openUrl: (url) => openLink('$url'))
          .functions['openUrl']!,
    ],
    themeSchema: basic.themeSchema,
    definitions: basic.definitions,
    protocolVersion: A2uiProtocolVersion.v0_9_1,
  );
}

/// [MdCarouselView] as an A2UI component: cards in a row that scrolls
/// sideways, each with a name, Markdown, and a 'Select' button that runs the
/// card's action.
///
/// Each card carries its own action, as a basic `Button` does, so the agent
/// learns from the action which card the user picked.
final ComponentImplementation mdCarousel = ComponentImplementation(
  name: 'MdCarousel',
  schema: Schema.fromMap({
    'type': 'object',
    'allOf': [
      {r'$ref': _Refs.componentCommon},
      {r'$ref': _Refs.catalogComponentCommon},
      {
        'type': 'object',
        'description':
            'Options side by side, as cards in a row that scrolls sideways. '
            'Each card shows a name above Markdown text, and a Select button '
            'when it has an action.',
        'properties': {
          'component': {'const': 'MdCarousel'},
          'items': {
            'type': 'array',
            'description': 'The cards, in the order they are shown.',
            'minItems': 1,
            'items': {
              'type': 'object',
              'properties': {
                'name': {
                  'type': 'string',
                  'description':
                      'Shown at the top of the card. No two cards may share '
                      'a name.',
                },
                'markdown': {
                  'type': 'string',
                  'description':
                      'Shown below the name. A few short lines fit without '
                      'scrolling.',
                },
                'action': {
                  r'$ref': _Refs.action,
                  'description': "Runs when the user presses 'Select'.",
                },
              },
              'required': ['name', 'markdown'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['component', 'items'],
      },
    ],
    'unevaluatedProperties': false,
  }),
  builder: (context, node, props, buildChild) {
    final Map<String, String> cards = {};
    final Map<String, Future<void> Function()> actions = {};
    for (final Map<String, Object?> item
        in props.list('items').whereType<Map<String, Object?>>()) {
      final String name = ComponentProps.asString(item['name']) ?? '';
      cards[name] = ComponentProps.asString(item['markdown']) ?? '';
      if (item['action'] case final Future<void> Function() action) {
        actions[name] = action;
      }
    }
    return MdCarouselView(
      items: cards,
      onSelect: actions.isEmpty ? null : (name, _) => actions[name]?.call(),
    );
  },
);
