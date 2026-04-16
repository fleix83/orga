import { createRouter, createWebHashHistory } from 'vue-router'
import Login from './views/Login.vue'
import Kunden from './views/Kunden.vue'
import Auftraege from './views/Auftraege.vue'
import Dienstleistungen from './views/Dienstleistungen.vue'
import Inventar from './views/Inventar.vue'
import Aufwand from './views/Aufwand.vue'
import Geschaeftszahlen from './views/Geschaeftszahlen.vue'
import Termine from './views/Termine.vue'

const routes = [
  { path: '/login', component: Login, meta: { noAuth: true } },
  { path: '/', redirect: '/kunden' },
  { path: '/kunden', component: Kunden },
  { path: '/auftraege', component: Auftraege },
  { path: '/dienstleistungen', component: Dienstleistungen },
  { path: '/inventar', component: Inventar },
  { path: '/aufwand', component: Aufwand },
  { path: '/geschaeftszahlen', component: Geschaeftszahlen },
  { path: '/termine', component: Termine },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

export default router
