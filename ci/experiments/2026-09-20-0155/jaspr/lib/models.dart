/// The models the picker offers, and the choice it produces.
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

  ModelChoice copyWith({
    String? familyId,
    String? modelId,
    double? temperature,
    int? maxOutputTokens,
    String? apiKey,
  }) => ModelChoice(
    familyId: familyId ?? this.familyId,
    modelId: modelId ?? this.modelId,
    temperature: temperature ?? this.temperature,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
    apiKey: apiKey ?? this.apiKey,
  );
}

class ModelFamily {
  const ModelFamily({
    required this.id,
    required this.label,
    required this.note,
    required this.models,
    required this.needsKey,
  });

  final String id;
  final String label;
  final String note;
  final List<({String id, String label})> models;
  final bool needsKey;
}

const families = <ModelFamily>[
  ModelFamily(
    id: 'gemini',
    label: 'Gemini',
    note: 'Runs in the cloud. Needs an API key, which stays in this browser tab.',
    models: [
      (id: 'gemini-flash-latest', label: 'gemini-flash-latest (recommended)'),
      (id: 'gemini-flash-lite-latest', label: 'gemini-flash-lite-latest'),
    ],
    needsKey: true,
  ),
  ModelFamily(
    id: 'local',
    label: 'In this browser',
    note: 'Loads a model with WebLLM through JavaScript interop. No key, a long '
        'first load, and weaker answers.',
    models: [
      (id: 'Llama-3.2-3B-Instruct-q4f16_1-MLC', label: 'Llama 3.2 3B'),
    ],
    needsKey: false,
  ),
];

/// What the picker opens on: the model the experiment is run with.
const defaultChoice = ModelChoice(
  familyId: 'gemini',
  modelId: 'gemini-flash-latest',
  temperature: 0.7,
  maxOutputTokens: 4096,
);

/// The key the app was compiled with, when one was given.
///
/// A browser app has no environment, so this is the nearest thing:
/// `--define=GEMINI_API_KEY=...` at build time. Left unset, the picker asks.
const envApiKey = String.fromEnvironment('GEMINI_API_KEY');
