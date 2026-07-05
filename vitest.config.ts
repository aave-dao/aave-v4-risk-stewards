import {defineConfig} from 'vitest/config';

export default defineConfig({
  test: {
    include: ['generator/**/*.spec.ts'],
    exclude: ['node_modules/**', 'lib/**', 'tmp-for-ref/**'],
  },
});
