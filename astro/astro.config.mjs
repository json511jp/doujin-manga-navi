// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import react from '@astrojs/react';
import cloudflare from '@astrojs/cloudflare';
import { siteConfig } from '../site.config.js';

export default defineConfig({
  site: siteConfig.siteUrl,
  output: 'server',
  adapter: cloudflare({ imageService: 'passthrough', sessionKVBindingName: undefined }),
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [react()],
});
