<template>
  <div v-if="loading" />
  <div v-else-if="isLoginPage">
    <router-view />
  </div>
  <div v-else class="app-layout">
    <button class="menu-toggle" @click="sidebarOpen = true" aria-label="Menü">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round">
        <line x1="4" y1="7" x2="20" y2="7"/>
        <line x1="4" y1="12" x2="20" y2="12"/>
        <line x1="4" y1="17" x2="20" y2="17"/>
      </svg>
    </button>
    <div class="sidebar-backdrop" :class="{ open: sidebarOpen }" @click="sidebarOpen = false"></div>
    <Sidebar :open="sidebarOpen" @close="sidebarOpen = false" />
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { api } from './api.js'
import Sidebar from './components/Sidebar.vue'

const router = useRouter()
const route = useRoute()
const loading = ref(true)
const authenticated = ref(false)
const sidebarOpen = ref(false)

const isLoginPage = computed(() => route.path === '/login')

onMounted(async () => {
  try {
    const res = await api.get('auth.php?action=check')
    authenticated.value = res.authenticated
  } catch {
    authenticated.value = false
  }

  if (!authenticated.value && route.path !== '/login') {
    router.push('/login')
  }
  loading.value = false
})

router.beforeEach((to) => {
  if (!to.meta.noAuth && !authenticated.value && !loading.value) {
    return '/login'
  }
})

watch(() => route.path, (path) => {
  if (path !== '/login') {
    authenticated.value = true
  }
  sidebarOpen.value = false
})
</script>
