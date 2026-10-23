import react from '@vitejs/plugin-react';
import {defineConfig} from 'vitest/config';

export default defineConfig({
  plugins: [react()],

  // Builds GEMINI_API_KEY from the environment into the app, the way
  // --dart-define does for the Flutter version.
  envPrefix: 'GEMINI_API_KEY',

  // The system prompt is read from simple_chat/doc, outside this app.
  server: {fs: {allow: ['../../..']}},

  test: {environment: 'jsdom', setupFiles: ['test/setup.ts']},
});
