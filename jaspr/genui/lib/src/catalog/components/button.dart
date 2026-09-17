import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../catalog_item.dart';
import '../schemas.dart';

/// A button that runs an action when pressed.
final CatalogItem buttonItem = CatalogItem(
  name: 'Button',
  schema: Schema.object(
    description: 'A button that triggers an action when pressed.',
    properties: {
      'child': A2uiSchemas.componentId(
        description:
            'The ID of the component shown inside the button, usually a '
            'Text component.',
      ),
      'action': A2uiSchemas.action(),
      'variant': Schema.string(
        description: 'How prominent the button is.',
        enumValues: ['primary', 'borderless'],
      ),
      'checks': A2uiSchemas.checks(),
    },
    required: ['child', 'action'],
  ),
  builder: (context) {
    final void Function()? action = context.action('action');
    final String variant = context.string('variant') ?? 'primary';
    // A button whose checks fail is the one thing standing between an
    // incomplete form and a round trip to the model, so it stays disabled
    // and says why rather than submitting what it has.
    final List<String> errors = context.validationErrors;
    final bool enabled = context.isValid && action != null;

    return Component.element(
      tag: 'div',
      classes: 'a2ui-button-wrap',
      children: [
        Component.element(
          tag: 'button',
          classes: 'a2ui-button a2ui-button-$variant',
          attributes: {
            'type': 'button',
            if (!enabled) 'disabled': '',
            if (errors.isNotEmpty) 'title': errors.join('\n'),
          },
          events: enabled ? {'click': (_) => action()} : const {},
          children: [context.buildChild(context['child'])],
        ),
        if (errors.isNotEmpty)
          Component.element(
            tag: 'div',
            classes: 'a2ui-validation',
            children: [Component.text(errors.join(' '))],
          ),
      ],
    );
  },
);
