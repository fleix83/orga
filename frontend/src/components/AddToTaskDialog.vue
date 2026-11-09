<template>
  <div class="confirm-overlay" @click.self="$emit('close')">
    <div class="confirm-box">
      <h3>Zu Aufgabe hinzufügen</h3>

      <div class="seg-switch" role="tablist">
        <button
          type="button"
          role="tab"
          :aria-selected="mode === 'new'"
          :class="['seg-option', { active: mode === 'new' }]"
          @click="mode = 'new'"
        >Neue Aufgabe</button>
        <button
          type="button"
          role="tab"
          :aria-selected="mode === 'existing'"
          :class="['seg-option', { active: mode === 'existing' }]"
          @click="mode = 'existing'"
        >Bestehende Aufgabe</button>
      </div>

      <div v-if="mode === 'new'" class="form-group">
        <label>Titel</label>
        <input v-model="title" type="text" @keyup.enter="submit">
      </div>

      <div v-else class="form-group">
        <label>Aufgabe</label>
        <input v-model="search" type="search" placeholder="Aufgabe suchen …" class="task-search">
        <div class="task-list">
          <button
            v-for="t in filteredTasks"
            :key="t.id"
            type="button"
            :class="['task-option', { selected: t.id === taskId }]"
            @click="taskId = t.id"
          >
            <span :class="['task-dot', t.status]"></span>
            <span class="task-option-title">{{ t.title }}</span>
          </button>
          <div v-if="!filteredTasks.length" class="task-empty">Keine offenen Aufgaben gefunden</div>
        </div>
      </div>

      <div class="form-group">
        <label>Wird übernommen</label>
        <textarea v-model="text" rows="5"></textarea>
      </div>

      <div v-if="error" class="save-error">{{ error }}</div>

      <div class="form-actions">
        <button class="btn" @click="$emit('close')">Abbrechen</button>
        <button class="btn btn-primary" @click="submit">Hinzufügen</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'

// Links a booking (and its customer) to a new or existing task and appends
// the booking summary — date, customer, services, notes — to the task notes.
const props = defineProps({
  orderId: { type: Number, required: true },
  summary: { type: String, default: '' },
  defaultTitle: { type: String, default: '' },
})

const emit = defineEmits(['close', 'done'])

const mode = ref('new')
const title = ref(props.defaultTitle)
const text = ref(props.summary)
const tasks = ref([])
const search = ref('')
const taskId = ref(null)
const error = ref('')

onMounted(async () => {
  const all = await api.get('tasks.php')
  tasks.value = all.filter(t => t.status !== 'done')
})

const filteredTasks = computed(() => {
  const q = search.value.trim().toLowerCase()
  return q ? tasks.value.filter(t => t.title.toLowerCase().includes(q)) : tasks.value
})

async function submit() {
  const payload = { order_id: props.orderId, text: text.value }
  if (mode.value === 'new') {
    if (!title.value.trim()) {
      error.value = 'Bitte einen Titel eingeben.'
      return
    }
    payload.title = title.value.trim()
  } else {
    if (!taskId.value) {
      error.value = 'Bitte eine Aufgabe auswählen.'
      return
    }
    payload.task_id = taskId.value
  }
  try {
    const res = await api.post('tasks.php?action=attach_order', payload)
    emit('done', res.id)
  } catch (e) {
    error.value = e.message || 'Speichern fehlgeschlagen.'
  }
}
</script>

<style scoped>
.confirm-overlay {
  position: fixed;
  inset: 0;
  background: rgba(17, 24, 39, 0.35);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 120;
  backdrop-filter: blur(2px);
  -webkit-backdrop-filter: blur(2px);
}

.confirm-box {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  width: 90%;
  max-width: 460px;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
}

.confirm-box h3 {
  font-size: 17px;
  font-weight: 600;
  margin-bottom: 16px;
}

.seg-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4px;
  padding: 4px;
  margin-bottom: 18px;
  background: #f3f4f6;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
}

.seg-option {
  appearance: none;
  border: none;
  background: transparent;
  padding: 7px 10px;
  border-radius: 6px;
  font: inherit;
  font-size: 13px;
  font-weight: 500;
  color: #6b7280;
  cursor: pointer;
  white-space: nowrap;
}

.seg-option:hover { color: #111827; }

.seg-option.active {
  background: #fff;
  color: #111827;
  box-shadow: 0 1px 2px rgba(17, 24, 39, 0.08);
}

.task-search { margin-bottom: 6px; }

.task-list {
  max-height: 200px;
  overflow-y: auto;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 4px;
}

.task-option {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  appearance: none;
  border: none;
  background: transparent;
  text-align: left;
  padding: 8px 10px;
  border-radius: 6px;
  font: inherit;
  font-size: 14px;
  color: #111827;
  cursor: pointer;
}

.task-option:hover { background: #f9fafb; }
.task-option.selected { background: #f3f4f6; font-weight: 600; }

.task-option-title {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.task-dot {
  flex-shrink: 0;
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: #9ca3af;
}

.task-dot.doing { background: #728fef; }

.task-empty {
  padding: 10px;
  font-size: 13px;
  color: #9ca3af;
  text-align: center;
}

textarea { resize: vertical; font-size: 13px; }

.save-error {
  font-size: 13px;
  color: #dc2626;
}

.form-actions { margin-top: 16px; }
</style>
