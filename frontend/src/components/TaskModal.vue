<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <h2>{{ task.id ? 'Aufgabe bearbeiten' : 'Neue Aufgabe' }}</h2>

      <div class="form-group">
        <label>Titel</label>
        <MentionField
          ref="titleRef"
          v-model="form.title"
          :candidates="candidates"
          placeholder="Was ist zu tun? (@ für Kunde oder Buchung)"
          @mention="addLink"
          @enter="save"
        />
      </div>

      <div class="modal-grid">
        <div class="form-group">
          <label>Status</label>
          <div class="seg-switch" role="tablist">
            <button
              v-for="col in TASK_COLUMNS"
              :key="col.key"
              type="button"
              role="tab"
              :aria-selected="form.status === col.key"
              :class="['seg-option', { active: form.status === col.key }]"
              @click="form.status = col.key"
            >{{ col.label }}</button>
          </div>
        </div>
        <div class="form-group">
          <label>Fällig am</label>
          <input v-model="form.due_date" type="date">
        </div>
      </div>

      <div class="form-group">
        <label>Notizen</label>
        <MentionField
          v-model="form.notes"
          :candidates="candidates"
          multiline
          :rows="6"
          placeholder="Details, Schritte … mit @ Kunden oder Buchungen verknüpfen"
          @mention="addLink"
        />
      </div>

      <div class="form-group">
        <label>Verknüpft</label>
        <div v-if="form.links.length" class="link-list">
          <TaskLinkChip
            v-for="link in form.links"
            :key="linkKey(link)"
            :link="link"
            removable
            @open="$emit('open-link', $event)"
            @remove="removeLink"
          />
        </div>
        <div v-else class="link-empty">Noch nichts verknüpft – tippe @ im Titel oder in den Notizen.</div>
      </div>

      <div v-if="saveError" class="save-error">{{ saveError }}</div>

      <div class="form-actions">
        <button v-if="task.id" class="btn btn-danger delete-btn" @click="$emit('delete', task)">Löschen</button>
        <button class="btn" @click="$emit('close')">Abbrechen</button>
        <button class="btn btn-primary" @click="save">Speichern</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue'
import { api } from '../api.js'
import MentionField from './MentionField.vue'
import TaskLinkChip from './TaskLinkChip.vue'
import { linkKey } from '../utils/taskLinks.js'
import { TASK_COLUMNS } from '../utils/taskColumns.js'

const props = defineProps({
  task: { type: Object, default: () => ({}) },
  candidates: { type: Array, default: () => [] },
})

const emit = defineEmits(['close', 'saved', 'delete', 'open-link'])

const titleRef = ref(null)
const saveError = ref('')

const form = ref({
  title: props.task.title || '',
  notes: props.task.notes || '',
  status: props.task.status || 'todo',
  due_date: props.task.due_date ? String(props.task.due_date).slice(0, 10) : '',
  links: [...(props.task.links || [])],
})

onMounted(() => {
  if (!props.task.id) nextTick(() => titleRef.value?.focus())
})

function addLink(candidate) {
  if (!form.value.links.some(l => linkKey(l) === candidate.key)) {
    form.value.links.push({ ...candidate.link })
  }
}

function removeLink(link) {
  form.value.links = form.value.links.filter(l => linkKey(l) !== linkKey(link))
}

async function save() {
  if (!form.value.title.trim()) {
    saveError.value = 'Bitte einen Titel eingeben.'
    return
  }
  const payload = {
    title: form.value.title.trim(),
    notes: form.value.notes,
    status: form.value.status,
    due_date: form.value.due_date || null,
    links: form.value.links.map(l => (l.customer_id ? { customer_id: l.customer_id } : { order_id: l.order_id })),
  }
  try {
    if (props.task.id) {
      await api.put(`tasks.php?id=${props.task.id}`, payload)
    } else {
      await api.post('tasks.php', payload)
    }
    emit('saved')
  } catch (e) {
    saveError.value = e.message || 'Speichern fehlgeschlagen.'
  }
}
</script>

<style scoped>
.modal-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

@media (max-width: 560px) {
  .modal-grid { grid-template-columns: 1fr; }
}

.seg-switch {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;
  gap: 4px;
  padding: 4px;
  background: #f3f4f6;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
}

.seg-option {
  appearance: none;
  border: none;
  background: transparent;
  padding: 7px 8px;
  border-radius: 6px;
  font: inherit;
  font-size: 13px;
  font-weight: 500;
  color: #6b7280;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.12s ease, color 0.12s ease, box-shadow 0.12s ease;
}

.seg-option:hover { color: #111827; }

.seg-option.active {
  background: #fff;
  color: #111827;
  box-shadow: 0 1px 2px rgba(17, 24, 39, 0.08);
}

.link-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.link-empty {
  font-size: 13px;
  color: #9ca3af;
}

.save-error {
  margin-top: 12px;
  font-size: 13px;
  color: #dc2626;
}

.delete-btn { margin-right: auto; }
</style>
