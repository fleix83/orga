<template>
  <div>
    <div class="page-header">
      <h1>Termine</h1>
      <button class="btn btn-primary" @click="openModal">+ Neuer Termin</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th>Datum</th>
          <th>Uhrzeit</th>
          <th>Typ</th>
          <th>Kunde</th>
          <th>Dienstleistungen</th>
          <th>Notizen</th>
          <th style="text-align:right">CHF</th>
          <th>Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in appointments" :key="t.id">
          <td>{{ t.event_date }}</td>
          <td>{{ t.time_display }}</td>
          <td><span class="badge" :style="{ background: t.color + '33', color: t.color }">{{ t.event_type }}</span></td>
          <td>{{ t.customer_first_name ? `${t.customer_first_name} ${t.customer_last_name}` : '–' }}</td>
          <td>{{ t.service_names || '–' }}</td>
          <td><InlineEdit v-model="t.notes" @update:model-value="v => updateNotes(t, v)" /></td>
          <td style="text-align:right">{{ t.total_price ? Number(t.total_price).toFixed(2) : '–' }}</td>
          <td>
            <select :value="t.status" @change="updateStatus(t, $event.target.value)" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:13px">
              <option value="pending">Ausstehend</option>
              <option value="confirmed">Bestätigt</option>
              <option value="completed">Abgeschlossen</option>
              <option value="cancelled">Abgesagt</option>
            </select>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(t)">✕</button></td>
        </tr>
      </tbody>
    </table>
    </div>

    <ConfirmDialog
      :visible="!!deleteTarget"
      message="Termin wirklich löschen?"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />

    <!-- New appointment modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal">
        <h2>Neuer Termin</h2>
        <form @submit.prevent="saveAppointment">
          <div class="form-grid-2">
            <div class="form-group">
              <label>Datum</label>
              <input type="date" v-model="form.event_date" required />
            </div>
            <div class="form-group">
              <label>Status</label>
              <select v-model="form.status">
                <option value="confirmed">Bestätigt</option>
                <option value="pending">Ausstehend</option>
              </select>
            </div>
            <div class="form-group">
              <label>Startzeit</label>
              <select v-model="form.start_slot">
                <option v-for="h in startHours" :key="h" :value="h">{{ String(h).padStart(2, '0') }}:00</option>
              </select>
            </div>
            <div class="form-group">
              <label>Endzeit</label>
              <select v-model="form.end_slot">
                <option v-for="h in endHours" :key="h" :value="h">{{ String(h).padStart(2, '0') }}:00</option>
              </select>
            </div>
          </div>
          <div class="form-group">
            <label>Titel (optional)</label>
            <input type="text" v-model="form.title" placeholder="z.B. Beratung, Sitzung …" />
          </div>
          <div class="form-group">
            <label>Kunde (optional)</label>
            <select v-model="form.customer_id">
              <option value="">Kein Kunde</option>
              <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.first_name }} {{ c.last_name }}</option>
            </select>
          </div>
          <div class="form-group">
            <label>Notizen</label>
            <textarea v-model="form.notes" rows="3" placeholder="Optionale Notizen …"></textarea>
          </div>
          <div class="form-actions">
            <button type="button" class="btn" @click="closeModal">Abbrechen</button>
            <button type="submit" class="btn btn-primary" :disabled="saving">{{ saving ? 'Speichern …' : 'Speichern' }}</button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const appointments = ref([])
const customers = ref([])
const deleteTarget = ref(null)
const showModal = ref(false)
const saving = ref(false)

const defaultForm = () => ({
  event_date: new Date().toISOString().slice(0, 10),
  start_slot: 9,
  end_slot: 10,
  title: '',
  customer_id: '',
  notes: '',
  status: 'confirmed',
})

const form = ref(defaultForm())

const startHours = Array.from({ length: 14 }, (_, i) => i + 8)  // 8–21
const endHours = computed(() => Array.from({ length: 14 }, (_, i) => i + 9).filter(h => h > form.value.start_slot))  // 9–22, must be after start

onMounted(async () => {
  appointments.value = await api.get('appointments.php')
  customers.value = await api.get('customers.php')
})

function openModal() {
  form.value = defaultForm()
  showModal.value = true
}

function closeModal() {
  showModal.value = false
}

async function saveAppointment() {
  saving.value = true
  try {
    await api.post('appointments.php', {
      event_date: form.value.event_date,
      start_slot: Number(form.value.start_slot),
      end_slot: Number(form.value.end_slot),
      customer_id: form.value.customer_id || null,
      title: form.value.title || null,
      notes: form.value.notes || null,
      status: form.value.status,
    })
    appointments.value = await api.get('appointments.php')
    closeModal()
  } finally {
    saving.value = false
  }
}

async function updateStatus(appointment, status) {
  appointment.status = status
  await api.put(`appointments.php?id=${appointment.id}`, { status })
}

async function updateNotes(appointment, notes) {
  await api.put(`appointments.php?id=${appointment.id}`, { notes })
}

function confirmDelete(t) { deleteTarget.value = t }

async function doDelete() {
  await api.del(`appointments.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  appointments.value = await api.get('appointments.php')
}
</script>

<style scoped>
.form-grid-2 {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 16px;
}
</style>
