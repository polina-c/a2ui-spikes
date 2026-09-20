import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import 'models.dart';

/// Step 2 of the CUJ: the app opens here, with defaults that work.
class Picker extends StatefulComponent {
  const Picker({required this.onStart, super.key});

  final void Function(ModelChoice choice) onStart;

  @override
  State<Picker> createState() => _PickerState();
}

class _PickerState extends State<Picker> {
  ModelChoice _choice = defaultChoice;
  String _key = envApiKey;

  ModelFamily get _family =>
      families.firstWhere((f) => f.id == _choice.familyId);

  bool get _ready => _family.id == 'gemini' && _key.trim().isNotEmpty;

  @override
  Component build(BuildContext context) {
    return div(classes: 'picker', [
      h1([Component.text('Just Shining')]),
      p(classes: 'lead', [
        Component.text(
          'Pick the model that answers you. The defaults are the ones we '
          'recommend.',
        ),
      ]),
      div(classes: 'families', [
        for (final family in families)
          button(
            classes: family.id == _choice.familyId ? 'family chosen' : 'family',
            events: {
              'click': (_) => setState(() {
                _choice = _choice.copyWith(
                  familyId: family.id,
                  modelId: family.models.first.id,
                );
              }),
            },
            [
              strong([Component.text(family.label)]),
              span([Component.text(family.note)]),
            ],
          ),
      ]),
      label([
        Component.text('Model'),
        select(
          value: _choice.modelId,
          events: {
            'change': (event) => setState(() {
              _choice = _choice.copyWith(modelId: _selectValue(event));
            }),
          },
          [
            for (final model in _family.models)
              option(value: model.id, [Component.text(model.label)]),
          ],
        ),
      ]),
      div(classes: 'row', [
        label([
          Component.text('Temperature'),
          input(
            type: InputType.number,
            value: _choice.temperature.toString(),
            attributes: const {'step': '0.1', 'min': '0', 'max': '2'},
            events: {
              'change': (event) {
                final parsed = double.tryParse(_inputValue(event));
                if (parsed != null) {
                  _choice = _choice.copyWith(temperature: parsed);
                }
              },
            },
          ),
        ]),
        label([
          Component.text('Max output tokens'),
          input(
            type: InputType.number,
            value: _choice.maxOutputTokens.toString(),
            attributes: const {'step': '256', 'min': '256'},
            events: {
              'change': (event) {
                final parsed = int.tryParse(_inputValue(event));
                if (parsed != null) {
                  _choice = _choice.copyWith(maxOutputTokens: parsed);
                }
              },
            },
          ),
        ]),
      ]),
      if (_family.needsKey && envApiKey.isEmpty)
        label([
          Component.text('Gemini API key'),
          input(
            // Behind dots, so the key is never on screen or in a recording.
            type: InputType.password,
            attributes: const {'placeholder': 'Paste your key'},
            events: {'input': (event) => setState(() => _key = _inputValue(event))},
          ),
          span(classes: 'hint', [
            Component.text(
              'Kept in this tab only, and sent nowhere but Google.',
            ),
          ]),
        ]),
      if (_family.id != 'gemini')
        p(classes: 'hint', [
          Component.text(
            'The local family is listed for completeness. This build only '
            'speaks to Gemini.',
          ),
        ]),
      button(
        classes: 'start',
        attributes: _ready ? const {} : const {'disabled': ''},
        events: {
          'click': (_) {
            if (_ready) {
              component.onStart(_choice.copyWith(apiKey: _key.trim()));
            }
          },
        },
        [Component.text('Start the chat')],
      ),
    ]);
  }
}

/// Reads the value out of an input event.
///
/// The target is cast to the element type from `package:web` rather than read
/// through `dynamic`: a dynamic read analyzes cleanly and then returns nothing
/// once compiled to JavaScript, which cost the 2026-09-19-1347 run an
/// afternoon.
String _inputValue(web.Event event) =>
    (event.target as web.HTMLInputElement).value;

String _selectValue(web.Event event) =>
    (event.target as web.HTMLSelectElement).value;
