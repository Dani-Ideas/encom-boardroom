import { defineConfig } from 'vite'

// Shared by vite.min.config.js. encom-globe is the local hex-globe fork
// (file:../encom-globe), so three must be deduped or the globe would bundle
// its own copy from ../encom-globe/node_modules.
export function config(minify) {
  return {
    define: {
      'process.env.NODE_ENV': JSON.stringify('production'),
    },
    resolve: {
      dedupe: ['three'],
    },
    build: {
      lib: {
        entry: './src/main.js',
        name: '_encomBoardroom',
        formats: ['iife'],
        fileName: () => (minify ? 'encom-boardroom.min.js' : 'encom-boardroom.js'),
      },
      outDir: 'build',
      emptyOutDir: false,
      minify: minify ? 'esbuild' : false,
      commonjsOptions: {
        include: [/.*/],
        transformMixedEsModules: true,
      },
      rollupOptions: {
        output: {
          strict: false,
        },
      },
    },
  }
}

export default defineConfig(config(false))
