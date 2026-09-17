import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:json_schema_builder/json_schema_builder.dart';

/// Schema fragments for catalog components, on top of [core.CommonSchemas].
///
/// These shapes are not only documentation for the model. `a2ui_core`'s
/// binder reads them to classify each property: a schema that admits a
/// `{"path": ...}` object becomes a live data binding, one that admits an
/// `event` becomes a callback, and one that admits a `componentId` becomes a
/// child. A property declared as a plain [Schema.string] is a constant, and
/// no amount of correct JSON from the model will make it update.
abstract final class A2uiSchemas {
  /// A string, a data binding, or a function call.
  static Schema string({String? description}) =>
      _dynamic(Schema.string(), description);

  /// A number, a data binding, or a function call.
  static Schema number({String? description}) =>
      _dynamic(Schema.number(), description);

  /// A boolean, a data binding, or a function call.
  static Schema boolean({String? description}) =>
      _dynamic(Schema.boolean(), description);

  /// A list of [items], a data binding, or a function call.
  static Schema list({required Schema items, String? description}) =>
      _dynamic(Schema.list(items: items), description);

  /// A reference to another component by ID.
  static Schema componentId({String? description}) =>
      Schema.string(description: description ?? 'The ID of another component.');

  /// A list of children: either explicit IDs, or a template bound to a list
  /// in the data model, which renders one child per item.
  static Schema children({String? description}) => Schema.combined(
    description:
        description ??
        'Either a list of component IDs, or a template that renders the '
            'component `componentId` once per item at `path`.',
    anyOf: [
      Schema.list(items: componentId()),
      Schema.object(
        properties: {
          'componentId': componentId(),
          'path': Schema.string(
            description: 'Path to a list in the data model.',
          ),
        },
        required: ['componentId', 'path'],
      ),
    ],
  );

  /// Something to do when the user interacts with a component.
  static Schema action({String? description}) => Schema.combined(
    description: description ?? 'What happens when the user activates this.',
    anyOf: [
      Schema.object(
        properties: {
          'event': Schema.object(
            properties: {
              'name': Schema.string(
                description: 'The name of the event to send.',
              ),
              'context': Schema.object(
                description: 'Values to send along with the event.',
                additionalProperties: true,
              ),
            },
            required: ['name'],
          ),
        },
        required: ['event'],
      ),
      Schema.object(
        properties: {'functionCall': core.CommonSchemas.functionCall},
        required: ['functionCall'],
      ),
    ],
  );

  /// Conditions that must hold for the component's value to be valid.
  ///
  /// Used as the value of a `checks` property, which the binder recognises
  /// by name: it evaluates each condition and leaves the outcome in
  /// `isValid` and `validationErrors` for the component to render.
  static Schema checks() => Schema.list(
    description: 'Conditions the value must satisfy to be valid.',
    items: Schema.object(
      properties: {
        'condition': boolean(
          description: 'Must evaluate to true for the value to be valid.',
        ),
        'message': Schema.string(
          description: 'Shown to the user when the condition fails.',
        ),
      },
      required: ['condition', 'message'],
    ),
  );

  static Schema _dynamic(Schema literal, String? description) =>
      Schema.combined(
        description: description,
        anyOf: [
          literal,
          core.CommonSchemas.dataBinding,
          core.CommonSchemas.functionCall,
        ],
      );
}
