import 'package:jaspr/dom.dart';
import 'package:web/web.dart' as web;
import 'package:jaspr/jaspr.dart';

import 'models.dart';

/// The key compiled in with --dart-define, if there was one.
const String envKey = String.fromEnvironment('GEMINI_API_KEY');

class Picker extends StatefulComponent {
  const Picker({required this.onStart, super.key});

  final void Function(ModelChoice) onStart;

  @override
  State<Picker> createState() => _PickerState();
}

class _PickerState extends State<Picker> {
  ModelFamily _family = defaultFamily;
  ModelOption _model = defaultModel;
  Map<String, double> _params = {
    for (final p in defaultModel.params) p.key: p.value,
  };
  String _key = envKey;

  bool get _needsKey => _family.id == 'gemini' && envKey.isEmpty;
  bool get _ready => !_needsKey || _key.trim().isNotEmpty;

  void _pickFamily(ModelFamily f) => setState(() {
    _family = f;
    _model = f.models.first;
    _params = {for (final p in _model.params) p.key: p.value};
  });

  void _pickModel(ModelOption m) => setState(() {
    _model = m;
    _params = {for (final p in m.params) p.key: p.value};
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'panel', [
      h1([Component.text('Just Shining')]),
      p(classes: 'lead', [
        Component.text(
          'Pick the model that will answer you. The defaults are already '
          'chosen, so you can go straight to the chat.',
        ),
      ]),

      h2([Component.text('Model family')]),
      div(classes: 'row', [
        for (final f in families)
          button(
            classes: f.id == _family.id ? 'choice on' : 'choice',
            events: {'click': (_) => _pickFamily(f)},
            [
              strong([Component.text(f.label)]),
              span([Component.text(f.note)]),
            ],
          ),
      ]),

      h2([Component.text('Model')]),
      div(classes: 'col', [
        for (final m in _family.models)
          button(
            classes: m.id == _model.id ? 'choice wide on' : 'choice wide',
            events: {'click': (_) => _pickModel(m)},
            [
              strong([
                Component.text(
                  m.id == defaultModel.id && _family.id == defaultFamily.id
                      ? '${m.label} (default)'
                      : m.label,
                ),
              ]),
              span([Component.text(m.note)]),
            ],
          ),
      ]),

      h2([Component.text('Parameters')]),
      for (final spec in _model.params)
        label(classes: 'param', [
          span(classes: 'param-name', [Component.text(spec.label)]),
          input(
            type: InputType.range,
            attributes: {
              'min': '${spec.min}',
              'max': '${spec.max}',
              'step': '${spec.step}',
              'value': '${_params[spec.key] ?? spec.value}',
            },
            events: {
              'input': (event) {
                final value = double.tryParse(
                  (event.target as web.HTMLInputElement).value,
                );
                if (value != null) {
                  setState(() => _params[spec.key] = value);
                }
              },
            },
          ),
          span(classes: 'param-value', [
            Component.text(
              spec.step < 1
                  ? (_params[spec.key] ?? spec.value).toStringAsFixed(1)
                  : (_params[spec.key] ?? spec.value).round().toString(),
            ),
          ]),
          span(classes: 'param-range', [
            Component.text(
              'allowed ${spec.step < 1 ? spec.min.toStringAsFixed(1) : spec.min.round()}'
              ' to ${spec.step < 1 ? spec.max.toStringAsFixed(1) : spec.max.round()}',
            ),
          ]),
        ]),

      if (_needsKey) ...[
        h2([Component.text('Gemini API key')]),
        p(classes: 'lead', [
          Component.text(
            'No key was compiled in, so the app needs one to talk to Gemini. '
            'It stays in this browser tab.',
          ),
        ]),
        input(
          type: InputType.password,
          classes: 'key',
          attributes: {'placeholder': 'Paste your API key'},
          events: {
            'input': (event) => setState(
              () => _key = (event.target as web.HTMLInputElement).value,
            ),
          },
        ),
      ],
      if (_family.id == 'gemini' && envKey.isNotEmpty)
        p(classes: 'lead', [
          Component.text('A key was compiled in, so none is needed here.'),
        ]),

      button(
        classes: 'go',
        attributes: _ready ? {} : {'disabled': ''},
        events: {
          'click': (_) {
            if (!_ready) return;
            component.onStart(
              ModelChoice(
                familyId: _family.id,
                modelId: _model.id,
                temperature: _params['temperature'] ?? 0.7,
                maxOutputTokens: (_params['maxOutputTokens'] ?? 2048).round(),
                apiKey: _family.id == 'gemini'
                    ? (_key.isEmpty ? envKey : _key)
                    : null,
              ),
            );
          },
        },
        [Component.text('Start the chat')],
      ),
    ]);
  }
}
