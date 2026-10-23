declare global {
  interface ImportMetaEnv {
    /** Set by Vite when the app's config lists it in `envPrefix`. */
    readonly GEMINI_API_KEY?: string;
  }
}

/**
 * Takes the key from the `GEMINI_API_KEY` environment variable, which Vite
 * builds into the app.
 *
 * Returns an empty string when it is not set.
 */
export function loadGeminiApiKey(): string {
  return import.meta.env.GEMINI_API_KEY ?? '';
}
