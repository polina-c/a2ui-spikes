import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;

import '../catalog/catalog_item.dart';
import '../catalog/schemas.dart';
import '../primitives/embedded_schemas.g.dart';
import '../primitives/simple_items.dart';

/// Reusable pieces of system prompt.
abstract final class PromptFragments {
  /// Ask the model to respond to what the user said, not only with a UI.
  static String acknowledgeUser({String prefix = ''}) =>
      '${prefix}Acknowledge what the user said in your reply, in text, '
      'alongside any UI you generate.';

  /// Ask for a way to finish, whenever the UI asks for something.
  static String requireAtLeastOneSubmitElement({String prefix = ''}) =>
      '${prefix}Whenever you ask the user for information, include a button '
      'or another way for them to say they are done.';

  /// Tell the model today's date.
  static String currentDate({String prefix = ''}) =>
      '${prefix}Today is ${DateTime.now().toIso8601String().split('T').first}.';

  /// Rule out tool calls, for models that would otherwise reach for them.
  static String uiGenerationRestriction({String prefix = ''}) =>
      '${prefix}Do not use tools or function calls to generate UI. Emit A2UI '
      'JSON in fenced ```json blocks.';
}

/// How much of the A2UI specification to spell out in the system prompt.
///
/// The full protocol schemas run to several thousand tokens. A large hosted
/// model can take them and benefits from the precision; a small model
/// running in the browser has a context window those schemas would fill,
/// leaving no room for the conversation. This is the knob for that trade,
/// and it is the main thing the web port has that the Flutter one does not.
enum PromptDetail {
  /// The catalog, the message shapes, and worked examples. No raw schemas.
  ///
  /// The default, because the models that run in a browser are small.
  compact,

  /// Everything in [compact], plus the A2UI common types and message
  /// schemas in full, as the Flutter package sends them.
  full,
}

/// Builds the system prompt that teaches a model to drive a catalog.
///
/// What goes in is the catalog: its components' schemas become the menu of
/// what the model may emit, and its prompt fragments carry the rules the
/// schemas cannot state.
final class PromptBuilder {
  /// Creates a [PromptBuilder] for a chat, where each turn creates a new
  /// surface rather than editing the last one.
  ///
  /// Chat transcripts scroll, so an edited surface would change a message
  /// the user has already read and moved past.
  PromptBuilder.chat({
    required this.catalog,
    this.systemPromptFragments = const [],
    this.detail = PromptDetail.compact,
    this.importancePrefix = defaultImportancePrefix,
  }) : allowUpdates = false,
       allowDeletes = false;

  /// Creates a [PromptBuilder] with the surface operations spelled out.
  PromptBuilder.custom({
    required this.catalog,
    required this.allowUpdates,
    required this.allowDeletes,
    this.systemPromptFragments = const [],
    this.detail = PromptDetail.compact,
    this.importancePrefix = defaultImportancePrefix,
  });

  /// The prefix put on instructions that models tend to skip.
  static const String defaultImportancePrefix = 'IMPORTANT: ';

  /// The catalog the model may build from.
  final WebCatalog catalog;

  /// Extra prose, added ahead of everything the catalog contributes.
  final List<String> systemPromptFragments;

  /// How much of the protocol to spell out.
  final PromptDetail detail;

  /// The prefix put on instructions that models tend to skip.
  final String importancePrefix;

  /// Whether the model may change a surface it already sent.
  final bool allowUpdates;

  /// Whether the model may delete a surface.
  final bool allowDeletes;

  /// The system prompt, section by section.
  List<String> systemPrompt() {
    return [
      ...systemPromptFragments,
      'You answer the user with generated UI as well as words. You emit '
          'A2UI messages as JSON in fenced ```json blocks; each block holds '
          'exactly one message.',
      'The catalog to build from is "${catalog.id}". Use this exact string '
          'as the `catalogId` when creating a surface.',
      PromptFragments.uiGenerationRestriction(prefix: importancePrefix),
      ..._messageRules(),
      ...catalog.systemPromptFragments,
      if (detail == PromptDetail.compact)
        _fenced(_valueTypes, sectionName: 'VALUE TYPES'),
      _fenced(_catalogSchema(), sectionName: 'CATALOG'),
      if (detail == PromptDetail.full) ...[
        _fenced(_clean(commonTypesSchemaJson), sectionName: 'COMMON TYPES'),
        _fenced(
          _clean(serverToClientSchemaJson),
          sectionName: 'MESSAGE SCHEMA',
        ),
      ],
    ].map((section) => section.trim()).toList();
  }

  /// The system prompt as one string.
  String systemPromptJoined({String sectionSeparator = '\n\n---\n\n'}) =>
      systemPrompt().join(sectionSeparator);

  List<String> _messageRules() {
    final messages = <String>[
      '`createSurface`: opens a surface. Needs `surfaceId` (a new unique '
          'one each time), `catalogId`, and `sendDataModel: true` so that '
          'what the user enters comes back to you.',
      '`updateComponents`: puts components on a surface. Needs `surfaceId` '
          'and `components`, and exactly one component must have `id: '
          '"root"`.',
      '`updateDataModel`: sets a value a component is bound to. Needs '
          '`surfaceId`, `path` and `value`.',
      if (allowDeletes) '`deleteSurface`: removes a surface. Needs `surfaceId`.',
    ];

    return [
      'Every message has `"version": "v0.9"` and exactly one of the message '
          'bodies below.\n\n${messages.map((m) => '- $m').join('\n')}',
      'To show a UI: send `createSurface` with a new `surfaceId`, then '
          '`updateComponents` with the components for it. Both messages go '
          'in the same reply, each in its own ```json block.',
      if (!allowUpdates)
        '${importancePrefix}Never modify a surface you sent earlier. When '
            'the UI needs to change, create a new surface with a new '
            '`surfaceId`.',
      if (allowUpdates)
        'To change a surface you already sent, send `updateComponents` with '
            'its existing `surfaceId`.',
    ];
  }

  /// The catalog as JSON: one entry per component with its properties, plus
  /// the functions a binding may call.
  ///
  /// In [PromptDetail.compact] the shared value types are printed by name
  /// and explained once in [_valueTypes]. Printed in full they would be
  /// expanded into every property of every component, which is most of what
  /// made the Flutter package's prompt as long as it is.
  String _catalogSchema() {
    final bool compact = detail == PromptDetail.compact;
    final components = <String, Object?>{
      for (final CatalogItem item in catalog.components.values)
        item.name: compact ? _compact(item.schema.value) : item.schema.value,
    };

    final functions = <String, Object?>{
      for (final core.FunctionImplementation fn in catalog.functions.values)
        fn.name: {
          'returnType': fn.returnType.jsonValue,
          'parameters': compact
              ? _compact(fn.argumentSchema.value)
              : fn.argumentSchema.value,
        },
    };

    return const JsonEncoder.withIndent('  ').convert({
      'catalogId': catalog.id,
      'components': components,
      if (functions.isNotEmpty) 'functions': functions,
      if (catalog.themeSchema != null) 'theme': catalog.themeSchema!.value,
    });
  }

  /// Replaces each tagged sub-schema with the name of the type it stands
  /// for, and folds the small fixed shapes onto one line each.
  ///
  /// The result is still JSON, so it reads as a specification rather than
  /// prose, but a component takes a dozen lines instead of a hundred.
  static Object? _compact(Object? node) {
    if (node is List) return node.map(_compact).toList();
    if (node is! Map) return node;

    final Map<String, Object?> map = node.cast<String, Object?>();

    final ({String name, String? description})? tag = A2uiSchemas.readTag(
      map['description'],
    );
    if (tag != null) {
      final String label = tag.description == null
          ? tag.name
          : '${tag.name}: ${tag.description}';
      // A list whose entries are specific to this component still has to
      // say what they look like, or the model is left guessing the shape of
      // an option or a tab. The shared types are described once in
      // [_valueTypes], so repeating their shape per component only costs
      // room the conversation needs.
      final Object? items = tag.name == 'DynamicList' ? _itemsOf(map) : null;
      if (items != null) return {'type': label, 'items': _compact(items)};
      return label;
    }

    // A leaf with nothing but a type and a description reads better as the
    // one line it amounts to.
    final Object? type = map['type'];
    if (type is String &&
        type != 'object' &&
        type != 'array' &&
        map['enum'] == null &&
        map.keys.every((k) => k == 'type' || k == 'description')) {
      final Object? description = map['description'];
      return description is String ? '$type: $description' : type;
    }

    // An enumeration is the one place where the values matter and the
    // JSON Schema around them does not.
    final Object? values = map['enum'];
    if (values is List && map['type'] == 'string') {
      final String choices = 'one of: ${values.join(' | ')}';
      final Object? description = map['description'];
      return description is String ? '$description ($choices)' : choices;
    }

    final result = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in map.entries) {
      // "type": "object" on something that lists its properties, and
      // "additionalProperties", tell the model nothing it cannot see.
      if (entry.key == 'additionalProperties') continue;
      if (entry.key == 'type' &&
          entry.value == 'object' &&
          map.containsKey('properties')) {
        continue;
      }
      if (entry.key == 'required' && entry.value is List) {
        result[entry.key] = (entry.value! as List).join(', ');
        continue;
      }
      result[entry.key] = _compact(entry.value);
    }
    return result;
  }

  /// The `items` schema of a list type, looking through the `anyOf` that a
  /// dynamic list is built from.
  static Object? _itemsOf(Map<String, Object?> map) {
    if (map['items'] != null) return map['items'];
    final Object? alternatives = map['anyOf'];
    if (alternatives is! List) return null;
    for (final Object? alternative in alternatives) {
      if (alternative is Map && alternative['items'] != null) {
        return alternative['items'];
      }
    }
    return null;
  }

  /// The types the compact catalog refers to by name.
  ///
  /// This is the short prose replacement for A2UI's common_types.json: the
  /// same rules, in the form a small model has room for.
  static const String _valueTypes = r'''
Several properties below are given as a type name rather than spelled out.

- `DynamicString`, `DynamicNumber`, `DynamicBoolean`, `DynamicList`: either
  a literal of that type, or `{"path": "/a/json/pointer"}` to bind it to the
  data model, or `{"call": "functionName", "args": {...}}` to compute it.
  A bound property tracks the data model: change the data and the UI follows.
  A property a user edits must be bound, or what they enter is lost.
- `ComponentId`: the `id` of another component in the same surface. That
  component must also be defined, in the same `updateComponents` list.
- `ChildList`: either `["id1", "id2"]`, or
  `{"componentId": "rowId", "path": "/items"}` to render the component
  `rowId` once per entry of the list at `/items`. Inside such a child,
  a relative path like `{"path": "name"}` reads that entry's field.
- `Action`: either `{"event": {"name": "eventName", "context": {...}}}` to
  send the event back, or `{"functionCall": {"call": "fn", "args": {...}}}`
  to run a catalog function.
- `Checks`: a list of `{"condition": DynamicBoolean, "message": "..."}`.
  While a condition is false the component shows the message, and a Button
  with a failing check stays disabled. Conditions are usually function
  calls, e.g. `{"call": "required", "args": {"value": {"path": "/x"}}}`.
''';

  /// The embedded schemas refer to each other by absolute URL, which reads
  /// as a fetchable address the model does not have. A bare filename is
  /// closer to the truth, since both files are in the prompt already.
  static String _clean(String schema) =>
      schema.replaceAll(commonTypesSchemaId, 'common_types.json');
}

String _fenced(String content, {required String sectionName}) {
  final String name = sectionName.toUpperCase().replaceAll(' ', '_');
  return '-----${name}_START-----\n${content.trim()}\n-----${name}_END-----';
}
