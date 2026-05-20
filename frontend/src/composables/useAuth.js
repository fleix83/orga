import { ref } from 'vue'
import { api } from '../api.js'

// Shared auth state across App.vue, Login.vue, and the router guard.
// Module-scoped refs act as a singleton store.
const authenticated = ref(false)
const ready = ref(false)

function setAuthenticated(value) {
  authenticated.value = !!value
}

async function checkAuth() {
  try {
    const res = await api.get('auth.php?action=check')
    authenticated.value = !!res.authenticated
  } catch {
    authenticated.value = false
  } finally {
    ready.value = true
  }
}

export function useAuth() {
  return { authenticated, ready, setAuthenticated, checkAuth }
}
