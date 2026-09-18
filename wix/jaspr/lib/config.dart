/// The knobs on the chat: which model, and what it says before it is asked.
///
/// The facts the assistant answers from are in
/// [`knowledge.dart`](knowledge.dart), not here.
library;

/// The WebLLM model the page runs.
///
/// This is the one decision that matters, because the visitor pays for it in
/// download size and in the GPU memory the model needs while running. The
/// README has the table; `Llama-3.2-1B` is the smallest one that answers a
/// business question without inventing contact details.
const String modelId = 'Llama-3.2-1B-Instruct-q4f16_1-MLC';

/// One-time download per visitor, in MB, per model.
///
/// Measured from the matching `mlc-ai` repositories on Hugging Face, and
/// used only to tell visitors what they are about to download. A model that
/// is not in here still works; the start panel just says less about it.
const Map<String, int> downloadMb = <String, int>{
  'SmolLM2-360M-Instruct-q4f16_1-MLC': 210,
  'Qwen2.5-0.5B-Instruct-q4f16_1-MLC': 290,
  'gemma3-1b-it-q4f16_1-MLC': 530,
  'Llama-3.2-1B-Instruct-q4f16_1-MLC': 700,
  'Llama-3.2-1B-Instruct-q4f32_1-MLC': 950,
  'Qwen2.5-1.5B-Instruct-q4f16_1-MLC': 1100,
};

/// The label in the widget header.
const String heading = 'Ask me anything';

/// The opening line.
///
/// Shown without calling the model, so the page has something to say before
/// the weights finish loading. It is display copy only: `chat_session.dart`
/// keeps it out of the history the model sees, and says why.
const String greeting = 'Hi! Ask me about the studio.';

/// How the assistant answers, as opposed to what it knows.
const String systemPrompt =
    "You are an assistant on a business's website. Answer the user's "
    'question directly and concretely. Do not repeat yourself, do not use '
    'filler pleasantries, and do not ask what is on the user\'s mind. Keep '
    'answers under three sentences unless asked for more.';
