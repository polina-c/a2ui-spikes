import 'package:flutter/material.dart';

import 'models.dart';

/// The key compiled in with --dart-define, if there was one.
const String envKey = String.fromEnvironment('GEMINI_API_KEY');

class PickerPage extends StatefulWidget {
  const PickerPage({super.key, required this.onStart});

  final void Function(ModelChoice) onStart;

  @override
  State<PickerPage> createState() => _PickerPageState();
}

class _PickerPageState extends State<PickerPage> {
  late ModelFamily _family = defaultFamily;
  late ModelOption _model = defaultModel;
  late Map<String, double> _params = {
    for (final p in defaultModel.params) p.key: p.value,
  };
  final TextEditingController _key = TextEditingController(text: envKey);

  bool get _needsKey => _family.id == 'gemini' && envKey.isEmpty;
  bool get _ready => !_needsKey || _key.text.trim().isNotEmpty;

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
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Just Shining', style: text.headlineSmall),
                    const SizedBox(height: 6),
                    Text(
                      'Pick the model that will answer you. The defaults are '
                      'already chosen, so you can go straight to the chat.',
                      style: text.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    _heading(context, 'Model family'),
                    Row(
                      children: [
                        for (final f in families) ...[
                          Expanded(
                            child: _Choice(
                              title: f.label,
                              note: f.note,
                              selected: f.id == _family.id,
                              onTap: () => _pickFamily(f),
                            ),
                          ),
                          if (f != families.last) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                    _heading(context, 'Model'),
                    for (final m in _family.models)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _Choice(
                          title: m.id == defaultModel.id
                              ? '${m.label} (default)'
                              : m.label,
                          note: m.note,
                          selected: m.id == _model.id,
                          onTap: () => _pickModel(m),
                        ),
                      ),
                    _heading(context, 'Parameters'),
                    for (final p in _model.params)
                      _Param(
                        spec: p,
                        value: _params[p.key] ?? p.value,
                        onChanged: (v) => setState(() => _params[p.key] = v),
                      ),
                    if (_needsKey) ...[
                      _heading(context, 'Gemini API key'),
                      Text(
                        'No key was compiled in, so the app needs one to talk '
                        'to Gemini. It stays in this browser tab.',
                        style: text.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _key,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Paste your API key',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    if (_family.id == 'gemini' && envKey.isNotEmpty)
                      Text(
                        'A key was compiled in, so none is needed here.',
                        style: text.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _ready
                            ? () => widget.onStart(
                                ModelChoice(
                                  familyId: _family.id,
                                  modelId: _model.id,
                                  temperature: _params['temperature'] ?? 0.7,
                                  maxOutputTokens:
                                      (_params['maxOutputTokens'] ?? 2048)
                                          .round(),
                                  apiKey: _family.id == 'gemini'
                                      ? (_key.text.isEmpty ? envKey : _key.text)
                                      : null,
                                ),
                              )
                            : null,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Start the chat'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, String s) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(
      s.toUpperCase(),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(letterSpacing: 1, color: Colors.black54),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? accent : Colors.black26,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _Param extends StatelessWidget {
  const _Param({
    required this.spec,
    required this.value,
    required this.onChanged,
  });

  final ParamSpec spec;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 160, child: Text(spec.label)),
            Expanded(
              child: Slider(
                min: spec.min,
                max: spec.max,
                divisions: ((spec.max - spec.min) / spec.step).round(),
                value: value.clamp(spec.min, spec.max),
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                spec.step < 1
                    ? value.toStringAsFixed(1)
                    : value.round().toString(),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 160, bottom: 8),
          child: Text(
            'allowed ${spec.step < 1 ? spec.min.toStringAsFixed(1) : spec.min.round()}'
            ' to ${spec.step < 1 ? spec.max.toStringAsFixed(1) : spec.max.round()}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
