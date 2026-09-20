import 'package:flutter/material.dart';

import 'models.dart';

/// Step 2 of the CUJ: the app opens here, with defaults that work.
class PickerPage extends StatefulWidget {
  const PickerPage({super.key, required this.onStart});

  final void Function(ModelChoice choice) onStart;

  @override
  State<PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<PickerPage> {
  ModelChoice _choice = defaultChoice;
  final _key = TextEditingController(text: envApiKey);

  ModelFamily get _family => families.firstWhere((f) => f.id == _choice.familyId);

  bool get _ready => !_family.needsKey || _key.text.trim().isNotEmpty;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Text('Just Shining', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Pick the model that answers you. The defaults are the ones we '
                'recommend.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (final family in families)
                Card(
                  color: family.id == _choice.familyId
                      ? theme.colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    title: Text(family.label),
                    subtitle: Text(family.note),
                    onTap: () => setState(() {
                      _choice = _choice.copyWith(
                        familyId: family.id,
                        modelId: family.models.first.id,
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _choice.modelId,
                // Model names are long enough to overflow a narrow window.
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Model'),
                items: [
                  for (final model in _family.models)
                    DropdownMenuItem(value: model.id, child: Text(model.label)),
                ],
                onChanged: (value) => setState(() {
                  if (value != null) _choice = _choice.copyWith(modelId: value);
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _choice.temperature.toString(),
                      decoration: const InputDecoration(labelText: 'Temperature'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null) {
                          _choice = _choice.copyWith(temperature: parsed);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _choice.maxOutputTokens.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Max output tokens',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null) {
                          _choice = _choice.copyWith(maxOutputTokens: parsed);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_family.needsKey && envApiKey.isEmpty)
                TextField(
                  controller: _key,
                  // Behind dots, so the key is not on screen or in a recording.
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API key',
                    helperText: 'Kept on this device, and sent only to Google.',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (!_family.needsKey)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'The model runs on this machine. Nothing is sent anywhere, '
                    'and the first run downloads a gigabyte or more before the '
                    'first answer.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _ready
                    ? () => widget.onStart(
                        _family.needsKey
                            ? _choice.copyWith(apiKey: _key.text.trim())
                            : _choice,
                      )
                    : null,
                child: const Text('Start the chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
