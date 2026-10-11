import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  // GitHub repository: raghav95nanda/ritualone
  base: '/ritualone/',
  plugins: [react()],
  build: { outDir: 'docs', emptyOutDir: true },
});
