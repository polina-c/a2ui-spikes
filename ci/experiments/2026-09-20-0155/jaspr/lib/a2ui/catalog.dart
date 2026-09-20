// The catalog this app offers the model.
//
// a2ui_core ships a minimal catalog - Text, Row, Column, Button, TextField -
// and nothing else, so the first decision a Jaspr app has to make is what its
// catalog is. This one is the minimal catalog with a Card added, because a
// question with its answers below it wants a box around it and the model
// reaches for Card whether or not it is offered.
//
// Choosing the catalog is the part a published renderer would have decided.
// Nothing checks that another Jaspr app would choose the same.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A box around a single child.
class CardApi extends ComponentApi {
  @override
  String get name => 'Card';

  @override
  Schema get schema => Schema.object(
    properties: {'child': CommonSchemas.componentId},
    required: ['child'],
  );
}

/// The minimal catalog plus Card, under this app's own catalog id.
Catalog<ComponentApi> appCatalog() {
  final minimal = MinimalCatalog();
  return Catalog<ComponentApi>(
    id: minimal.id,
    components: [...minimal.components.values, CardApi()],
    functions: minimal.functions.values.toList(),
    themeSchema: minimal.themeSchema,
  );
}
