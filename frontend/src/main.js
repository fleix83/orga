import { createApp } from 'vue'
import App from './App.vue'
import router from './router.js'
// Source Sans Pro (heute "Source Sans 3"), selbst gehostet — kein CDN nötig
import '@fontsource/source-sans-3/400.css'
import '@fontsource/source-sans-3/500.css'
import '@fontsource/source-sans-3/600.css'
import '@fontsource/source-sans-3/700.css'
import './style.css'

const app = createApp(App)
app.use(router)
app.mount('#app')
