import { defineConfig } from 'vite';
import path from 'node:path';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  resolve: { alias: { '@tensorflow/tfjs-tflite': path.resolve('node_modules/@tensorflow/tfjs-tflite/dist/tf-tflite.fesm.min.js') } },
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.png', 'apple-touch-icon.png', 'logo-sifa.png'],
      manifest: {
        name: 'SIFA Admin',
        short_name: 'SIFA Admin',
        description: 'Administration de l’application SIFA : statistiques, contenu, photos et modèle d’analyse.',
        lang: 'fr',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        background_color: '#f2f5f1',
        theme_color: '#0f7a56',
        icons: [
          { src: '/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: '/icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        navigateFallback: '/index.html',
        // Les appels à Supabase ne sont jamais mis en cache : les chiffres doivent toujours être frais.
        navigateFallbackDenylist: [/^\/api\//],
        globPatterns: ['**/*.{js,css,html,png,svg,woff2}'],
        globIgnores: ['tflite/**', 'modele/**'],
        maximumFileSizeToCacheInBytes: 3_000_000,
      },
    }),
  ],
  build: { chunkSizeWarningLimit: 900 },
});
