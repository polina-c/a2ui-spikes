import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';

// The knowledge base is imported with `?raw` from ci/domain, which is outside
// this app, so the dev server has to be allowed to read it.
export default defineConfig({
  plugins: [react()],
  server: {fs: {allow: ['../../../..']}},
});
