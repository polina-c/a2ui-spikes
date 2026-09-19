// The model families offered on the opening screen, with the range the UI
// allows for every parameter the user can change.

class ParamSpec {
  const ParamSpec({
    required this.key,
    required this.label,
    required this.min,
    required this.max,
    required this.step,
    required this.value,
  });

  final String key;
  final String label;
  final double min;
  final double max;
  final double step;
  final double value;
}

ParamSpec temperature(double v) => ParamSpec(
  key: 'temperature',
  label: 'Temperature',
  min: 0,
  max: 2,
  step: 0.1,
  value: v,
);

ParamSpec maxOutputTokens(double v) => ParamSpec(
  key: 'maxOutputTokens',
  label: 'Max output tokens',
  min: 256,
  max: 8192,
  step: 256,
  value: v,
);

class ModelOption {
  const ModelOption({
    required this.id,
    required this.label,
    required this.note,
    required this.params,
  });

  final String id;
  final String label;
  final String note;
  final List<ParamSpec> params;
}

class ModelFamily {
  const ModelFamily({
    required this.id,
    required this.label,
    required this.note,
    required this.models,
  });

  final String id;
  final String label;
  final String note;
  final List<ModelOption> models;
}

final List<ModelFamily> families = [
  ModelFamily(
    id: 'gemini',
    label: 'Gemini',
    note: 'Runs on Google servers. Needs an API key.',
    models: [
      ModelOption(
        id: 'gemini-flash-latest',
        label: 'Gemini Flash (latest)',
        note: 'The default. Fast, and reliable at emitting strict JSON.',
        params: [temperature(0.7), maxOutputTokens(4096)],
      ),
      ModelOption(
        id: 'gemini-pro-latest',
        label: 'Gemini Pro (latest)',
        note: 'Slower and stronger. Better at long chains of questions.',
        params: [temperature(0.7), maxOutputTokens(8192)],
      ),
      ModelOption(
        id: 'gemini-2.5-flash-lite',
        label: 'Gemini 2.5 Flash Lite',
        note: 'The cheapest, and the most likely to get the schema wrong.',
        params: [temperature(0.7), maxOutputTokens(4096)],
      ),
    ],
  ),
  ModelFamily(
    id: 'local',
    label: 'Local (WebLLM)',
    note: 'Runs in this browser through WebGPU. No key, no network after the '
        'download.',
    models: [
      ModelOption(
        id: 'Llama-3.2-3B-Instruct-q4f32_1-MLC',
        label: 'Llama 3.2 3B Instruct',
        note: 'About 2 GB to download the first time.',
        params: [temperature(0.7), maxOutputTokens(2048)],
      ),
      ModelOption(
        id: 'Phi-3.5-mini-instruct-q4f16_1-MLC',
        label: 'Phi 3.5 Mini Instruct',
        note: 'Smaller and quicker to load, weaker at strict JSON.',
        params: [temperature(0.7), maxOutputTokens(2048)],
      ),
    ],
  ),
];

final ModelFamily defaultFamily = families.first;
final ModelOption defaultModel = defaultFamily.models.first;

class ModelChoice {
  const ModelChoice({
    required this.familyId,
    required this.modelId,
    required this.temperature,
    required this.maxOutputTokens,
    this.apiKey,
  });

  final String familyId;
  final String modelId;
  final double temperature;
  final int maxOutputTokens;
  final String? apiKey;
}
