import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:universal_web/web.dart' as web;

import '../catalog_item.dart';
import '../schemas.dart';

/// A single- or multi-line text input.
final CatalogItem textFieldItem = CatalogItem(
  name: 'TextField',
  schema: Schema.object(
    description: 'A field the user types into.',
    properties: {
      'label': A2uiSchemas.string(description: 'The label for the field.'),
      'value': A2uiSchemas.string(
        description:
            'The value of the field. Bind this to a path in the data model '
            'so that what the user types can be read back later.',
      ),
      'variant': Schema.string(
        description:
            'The kind of input accepted: shortText (the default) is one '
            'line, longText is multi-line, number accepts digits, and '
            'obscured hides what is typed.',
        enumValues: ['shortText', 'longText', 'number', 'obscured'],
      ),
      'validationRegexp': Schema.string(
        description:
            'A regular expression the value must match in full. An empty '
            'field is exempt; use checks to require a value at all.',
      ),
      'checks': A2uiSchemas.checks(),
    },
    required: ['label'],
  ),
  builder: (context) {
    final String variant = context.string('variant') ?? 'shortText';
    final String value = context.string('value') ?? '';
    final List<String> errors = [
      ...context.validationErrors,
      ...?_regexpError(context, value),
    ];

    final Component control = switch (variant) {
      'longText' => textarea(
        // A textarea carries its value as its child text rather than as an
        // attribute, which is what puts a bound value on screen.
        [Component.text(value)],
        id: context.id,
        classes: 'a2ui-input a2ui-textarea',
        rows: 4,
        onInput: (String next) => context.setValue('value', next),
      ),
      // The number input reports a num, not a string, so it writes a num to
      // the data model. Left empty it reports NaN, which is not a value the
      // model should ever see.
      'number' => input<num>(
        type: InputType.number,
        id: context.id,
        classes: 'a2ui-input',
        value: value,
        onInput: (num next) =>
            context.setValue('value', next.isNaN ? null : next),
      ),
      _ => input<String>(
        type: variant == 'obscured' ? InputType.password : InputType.text,
        id: context.id,
        classes: 'a2ui-input',
        value: value,
        onInput: (String next) => context.setValue('value', next),
      ),
    };

    return _field(
      id: context.id,
      label: context.string('label'),
      errors: errors,
      control: control,
    );
  },
);

/// A checkbox bound to a boolean in the data model.
final CatalogItem checkBoxItem = CatalogItem(
  name: 'CheckBox',
  schema: Schema.object(
    description: 'A labelled checkbox for a yes/no choice.',
    properties: {
      'label': A2uiSchemas.string(description: 'The label for the checkbox.'),
      'value': A2uiSchemas.boolean(
        description: 'Whether the box is ticked. Bind this to a path.',
      ),
      'checks': A2uiSchemas.checks(),
    },
    required: ['label', 'value'],
  ),
  builder: (context) {
    final List<String> errors = context.validationErrors;
    return div(classes: 'a2ui-field a2ui-checkbox', [
      label([
        input<bool>(
          type: InputType.checkbox,
          checked: context.boolean('value') ?? false,
          onChange: (bool next) => context.setValue('value', next),
        ),
        Component.text(context.string('label') ?? ''),
      ]),
      if (errors.isNotEmpty) _validation(errors),
    ]);
  },
);

/// A slider over a numeric range.
final CatalogItem sliderItem = CatalogItem(
  name: 'Slider',
  schema: Schema.object(
    description: 'A slider for picking a number in a range.',
    properties: {
      'label': A2uiSchemas.string(description: 'The label for the slider.'),
      'value': A2uiSchemas.number(
        description: 'The current value. Bind this to a path.',
      ),
      'min': Schema.number(description: 'The minimum value. Defaults to 0.'),
      'max': Schema.number(description: 'The maximum value. Defaults to 1.'),
      'checks': A2uiSchemas.checks(),
    },
    required: ['value'],
  ),
  builder: (context) {
    final double min = context.number('min') ?? 0;
    final double max = context.number('max') ?? 1;
    final double value = (context.number('value') ?? min).clamp(min, max);
    // A slider over 0..1 needs a fine step and one over 0..100 does not, so
    // derive it from the range rather than making the model specify it.
    final double step = (max - min).abs() > 10 ? 1 : (max - min) / 100;

    return _field(
      id: context.id,
      label: context.string('label'),
      errors: context.validationErrors,
      control: div(classes: 'a2ui-slider', [
        input<num>(
          type: InputType.range,
          id: context.id,
          value: '$value',
          attributes: {'min': '$min', 'max': '$max', 'step': '$step'},
          onInput: (num next) {
            if (!next.isNaN) context.setValue('value', next);
          },
        ),
        Component.element(
          tag: 'output',
          children: [Component.text(_trimNumber(value))],
        ),
      ]),
    );
  },
);

/// A date, time, or date-and-time picker.
final CatalogItem dateTimeInputItem = CatalogItem(
  name: 'DateTimeInput',
  schema: Schema.object(
    description: 'A picker for a date, a time, or both.',
    properties: {
      'label': A2uiSchemas.string(description: 'The label for the input.'),
      'value': A2uiSchemas.string(
        description:
            'The selected value, as an ISO 8601 string. Bind this to a path.',
      ),
      'variant': Schema.string(
        description: 'What to pick.',
        enumValues: ['date', 'time', 'datetime'],
      ),
      'min': Schema.string(description: 'The earliest allowed value.'),
      'max': Schema.string(description: 'The latest allowed value.'),
      'checks': A2uiSchemas.checks(),
    },
    required: ['value'],
  ),
  builder: (context) {
    final String variant = context.string('variant') ?? 'date';
    final InputType type = switch (variant) {
      'time' => InputType.time,
      'datetime' => InputType.dateTimeLocal,
      _ => InputType.date,
    };

    return _field(
      id: context.id,
      label: context.string('label'),
      errors: context.validationErrors,
      // Read straight off the element rather than through Jaspr's typed
      // DateTime extraction: the browser already reports these fields as
      // ISO-shaped strings, which is what the schema asks for, and the
      // typed path throws on an empty field instead of reporting no value.
      control: Component.element(
        tag: 'input',
        id: context.id,
        classes: 'a2ui-input',
        attributes: {
          'type': type.value,
          'value': context.string('value') ?? '',
          'min': ?context.string('min'),
          'max': ?context.string('max'),
        },
        events: {
          'change': (web.Event event) {
            final web.EventTarget? target = event.target;
            // The listener is on the input itself, so the target is that
            // input; this is a cast, not a test, which is what the interop
            // lint is pointing out.
            // ignore: invalid_runtime_check_with_js_interop_types
            if (target is! web.HTMLInputElement) return;
            final String next = target.value;
            context.setValue('value', next.isEmpty ? null : next);
          },
        },
      ),
    );
  },
);

/// An image from a URL.
final CatalogItem imageItem = CatalogItem(
  name: 'Image',
  schema: Schema.object(
    description: 'An image loaded from a URL.',
    properties: {
      'url': A2uiSchemas.string(description: 'The URL of the image.'),
      'alt': A2uiSchemas.string(
        description: 'A description of the image, for screen readers.',
      ),
      'fit': Schema.string(
        description: 'How the image fills its box.',
        enumValues: ['contain', 'cover', 'fill'],
      ),
    },
    required: ['url'],
  ),
  builder: (context) => img(
    src: context.string('url') ?? '',
    alt: context.string('alt') ?? '',
    classes: 'a2ui-image',
    loading: MediaLoading.lazy,
    styles: Styles(raw: {'object-fit': context.string('fit') ?? 'contain'}),
  ),
);

Component _field({
  required String id,
  required String? label,
  required List<String> errors,
  required Component control,
}) {
  return div(classes: 'a2ui-field', [
    if (label != null && label.isNotEmpty)
      Component.element(
        tag: 'label',
        attributes: {'for': id},
        children: [Component.text(label)],
      ),
    control,
    if (errors.isNotEmpty) _validation(errors),
  ]);
}

Component _validation(List<String> errors) =>
    div(classes: 'a2ui-validation', [Component.text(errors.join(' '))]);

List<String>? _regexpError(A2uiBuildContext context, String value) {
  final String? pattern = context.string('validationRegexp');
  if (pattern == null || value.isEmpty) return null;
  try {
    if (RegExp('^(?:$pattern)\$').hasMatch(value)) return null;
    return const ['That is not a valid value.'];
  } on FormatException {
    // The pattern came from the model, so it may not be a regexp at all. A
    // field the user cannot possibly satisfy is worse than an unchecked one.
    return null;
  }
}

String _trimNumber(double value) {
  final String text = value.toStringAsFixed(2);
  return text.endsWith('.00') ? value.toStringAsFixed(0) : text;
}
