<template>
  <nav class="sidebar">
    <div class="sidebar-title">Orga</div>
    <router-link v-for="item in items" :key="item.path" :to="item.path" class="sidebar-link">
      {{ item.label }}
    </router-link>
    <button class="sidebar-logout" @click="logout">Abmelden</button>
  </nav>
</template>

<script setup>
import { useRouter } from 'vue-router'
import { api } from '../api.js'

const router = useRouter()

const items = [
  { path: '/auftraege', label: 'Aufträge' },
  { path: '/kunden', label: 'Kunden' },
  { path: '/dienstleistungen', label: 'Dienstleistungen' },
  { path: '/inventar', label: 'Inventar' },
  { path: '/aufwand', label: 'Aufwand' },
  { path: '/geschaeftszahlen', label: 'Geschäftszahlen' },
  { path: '/termine', label: 'Termine' },
]

async function logout() {
  await api.post('auth.php?action=logout')
  router.push('/login')
}
</script>

<style scoped>
.sidebar {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  width: 220px;
  background: #f9fafb;
  border-right: 1px solid #e5e7eb;
  padding: 20px 0;
  display: flex;
  flex-direction: column;
}
.sidebar-title { font-size: 18px; font-weight: 700; padding: 0 20px 20px; border-bottom: 1px solid #e5e7eb; margin-bottom: 8px; }
.sidebar-link { display: block; padding: 10px 20px; text-decoration: none; color: #374151; font-size: 14px; }
.sidebar-link:hover { background: #f3f4f6; }
.sidebar-link.router-link-active { color: #2563eb; background: #eff6ff; font-weight: 500; }
.sidebar-logout { margin-top: auto; padding: 10px 20px; border: none; background: none; color: #6b7280; cursor: pointer; text-align: left; font-size: 14px; }
.sidebar-logout:hover { color: #dc2626; }
</style>
