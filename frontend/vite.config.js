import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/orga/dist/',
  build: {
    outDir: '../dist',
    emptyOutDir: true
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:80',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '/orga/api')
      }
    }
  }
})
