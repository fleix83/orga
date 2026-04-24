import { ref } from 'vue'
import { api } from '../api.js'

const STORAGE_KEY = 'appointmentsLastSeenAt'

const hasNew = ref(false)
const newCount = ref(0)

function getLastSeen() {
  return localStorage.getItem(STORAGE_KEY) || ''
}

async function fetchCount(since) {
  const query = since ? `?new_count=1&since=${encodeURIComponent(since)}` : '?new_count=1'
  return api.get(`appointments.php${query}`)
}

async function refresh() {
  try {
    const res = await fetchCount(getLastSeen())
    newCount.value = res.count || 0
    hasNew.value = newCount.value > 0
  } catch {
    // Best-effort: never break the UI on a notification fetch error.
  }
}

async function markSeen() {
  try {
    const res = await fetchCount(null)
    if (res.server_time) localStorage.setItem(STORAGE_KEY, res.server_time)
  } catch {
    // Fall back to local time if the server is unreachable.
    const d = new Date()
    const pad = (n) => String(n).padStart(2, '0')
    const local = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
    localStorage.setItem(STORAGE_KEY, local)
  }
  hasNew.value = false
  newCount.value = 0
}

export function useAppointmentNotifications() {
  return { hasNew, newCount, refresh, markSeen }
}
