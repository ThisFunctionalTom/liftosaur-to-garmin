import { defineConfig } from 'vite';
import { offlineApp } from './pwa-build.js';

export default defineConfig({ base: './', plugins: [offlineApp()] });
