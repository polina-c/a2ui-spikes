import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../catalog_item.dart';
import '../schemas.dart';

/// Picks one or several options from a list.
///
/// This is the component a chat agent reaches for when it needs the user to
/// choose rather than to type, so it accepts its options either as a literal
/// list or as a binding to a list the agent put in the data model.
final CatalogItem choicePickerItem = CatalogItem(
  name: 'ChoicePicker',
  schema: Schema.object(
    description: 'Lets the user choose one or more options from a list.',
    properties: {
      'label': A2uiSchemas.string(
        description: 'The label for the group of options.',
      ),
      'options': A2uiSchemas.list(
        description: 'The options to choose from.',
        items: Schema.object(
          properties: {
            'label': A2uiSchemas.string(
              description: 'The text shown for this option.',
            ),
            'value': Schema.string(
              description: 'The value recorded when this option is chosen.',
            ),
          },
          required: ['label', 'value'],
        ),
      ),
      'value': A2uiSchemas.string(
        description:
            'The chosen value, or a list of them when multipleSelection is '
            'used. Bind this to a path.',
      ),
      'variant': Schema.string(
        description: 'Whether more than one option can be chosen at a time.',
        enumValues: ['mutuallyExclusive', 'multipleSelection'],
      ),
      'checks': A2uiSchemas.checks(),
    },
    required: ['options', 'value'],
  ),
  builder: (context) {
    final bool multiple = context.string('variant') == 'multipleSelection';
    final List<_Option> options = _optionsOf(context['options']);
    final Set<String> selected = _selectionOf(context['value']);
    final List<String> errors = context.validationErrors;

    void toggle(String value, bool isOn) {
      if (!multiple) {
        context.setValue('value', isOn ? value : null);
        return;
      }
      final Set<String> next = {...selected};
      if (isOn) {
        next.add(value);
      } else {
        next.remove(value);
      }
      context.setValue('value', next.toList());
    }

    final String? groupLabel = context.string('label');
    return div(classes: 'a2ui-field a2ui-choices', [
      if (groupLabel != null && groupLabel.isNotEmpty)
        div(classes: 'a2ui-choices-label', [Component.text(groupLabel)]),
      for (final (int index, _Option option) in options.indexed)
        label(classes: 'a2ui-choice', [
          input<bool>(
            // Radios in one group have to share a name, and the component's
            // own ID is the one name guaranteed unique on the surface.
            type: multiple ? InputType.checkbox : InputType.radio,
            name: '${context.id}-choice',
            value: option.value,
            checked: selected.contains(option.value),
            onChange: (bool isOn) => toggle(option.value, isOn),
            key: ValueKey<String>('${context.id}-$index-${option.value}'),
          ),
          Component.text(option.label),
        ]),
      if (errors.isNotEmpty)
        div(classes: 'a2ui-validation', [Component.text(errors.join(' '))]),
    ]);
  },
);

final class _Option {
  const _Option(this.label, this.value);
  final String label;
  final String value;
}

List<_Option> _optionsOf(Object? raw) {
  if (raw is! List) return const [];
  final options = <_Option>[];
  for (final Object? entry in raw) {
    if (entry is Map) {
      final Object? value = entry['value'];
      if (value == null) continue;
      options.add(_Option('${entry['label'] ?? value}', '$value'));
    } else if (entry != null) {
      // A model that was asked for options will sometimes send bare
      // strings. Reading them as label and value both is more useful than
      // rendering an empty list.
      options.add(_Option('$entry', '$entry'));
    }
  }
  return options;
}

Set<String> _selectionOf(Object? raw) => switch (raw) {
  final List<Object?> values => {
    for (final Object? value in values)
      if (value != null) '$value',
  },
  null => const {},
  final Object value => {'$value'},
};
