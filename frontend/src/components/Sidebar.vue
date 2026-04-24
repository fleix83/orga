<template>
  <nav class="sidebar" :class="{ open }">
    <div class="sidebar-title">Orga</div>
    <div class="sidebar-nav">
      <router-link
        v-for="item in items"
        :key="item.path"
        :to="item.path"
        class="sidebar-link"
        @click="$emit('close')"
      >
        {{ item.label }}
        <span v-if="item.path === '/termine' && hasNew" class="notification-dot" :title="`${newCount} neue Termine`"></span>
      </router-link>
    </div>
    <button class="sidebar-logout" @click="logout">Abmelden</button>
  </nav>
</template>

<script setup>
import { onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { api } from '../api.js'
import { useAppointmentNotifications } from '../composables/useAppointmentNotifications.js'

defineProps({ open: { type: Boolean, default: false } })
defineEmits(['close'])

const router = useRouter()
const route = useRoute()
const { hasNew, newCount, refresh } = useAppointmentNotifications()

const items = [
  { path: '/auftraege', label: 'Aufträge' },
  { path: '/kunden', label: 'Kunden' },
  { path: '/dienstleistungen', label: 'Dienstleistungen' },
  { path: '/inventar', label: 'Inventar' },
  { path: '/aufwand', label: 'Aufwand' },
  { path: '/geschaeftszahlen', label: 'Geschäftszahlen' },
  { path: '/termine', label: 'Termine' },
]

onMounted(refresh)
watch(() => route.path, refresh)

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
  background: #fafafa;
  border-right: 1px solid #f3f4f6;
  padding: 28px 0 16px;
  display: flex;
  flex-direction: column;
}

.sidebar-title {
  font-size: 17px;
  font-weight: 700;
  letter-spacing: -0.2px;
  padding: 0 24px 24px;
  color: #111827;
}

.sidebar-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 0 12px;
}

.sidebar-link {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 9px 14px;
  text-decoration: none;
  color: #4b5563;
  font-size: 14px;
  font-weight: 500;
  border-radius: 7px;
  transition: background 0.1s ease, color 0.1s ease;
}

.notification-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #dc2626;
}

.sidebar-link:hover {
  background: #f3f4f6;
  color: #111827;
}

.sidebar-link.router-link-active {
  color: #111827;
  background: #ffe98c78;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
}

.sidebar-logout {
  margin-top: auto;
  padding: 10px 24px;
  border: none;
  background: none;
  color: #9ca3af;
  cursor: pointer;
  text-align: left;
  font-size: 13px;
  font-weight: 500;
}

.sidebar-logout:hover { color: #dc2626; }

@media (max-width: 768px) {
  .sidebar {
    width: 240px;
    padding: 68px 0 24px;
    background: #fff;
  }
  .sidebar-title {
    display: none;
  }
  .sidebar-nav { padding: 0 16px; }
  .sidebar-link {
    padding: 12px 16px;
    font-size: 15px;
    border-radius: 8px;
  }
  .sidebar-logout {
    padding: 14px 24px;
    font-size: 14px;
  }
}
</style>
