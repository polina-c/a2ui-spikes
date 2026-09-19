import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';

// The domain knowledge lives at the repo root, three levels up, and is pulled in
// with `?raw` imports. Vite has to be told it may read from there.
export default defineConfig({
  plugins: [react()],
  server: {fs: {allow: ['../../..']}},
});
