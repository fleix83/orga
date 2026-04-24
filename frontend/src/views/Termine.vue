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
          <th :class="sortClass('event_date')" @click="toggleSort('event_date')">Datum</th>
          <th :class="sortClass('time_display')" @click="toggleSort('time_display')">Uhrzeit</th>
          <th :class="sortClass('event_type')" @click="toggleSort('event_type')">Typ</th>
          <th :class="sortClass('customer_last_name')" @click="toggleSort('customer_last_name')">Kunde</th>
          <th :class="sortClass('service_names')" @click="toggleSort('service_names')">Dienstleistungen</th>
          <th :class="sortClass('notes')" @click="toggleSort('notes')">Notizen</th>
          <th style="text-align:right" :class="sortClass('total_price')" @click="toggleSort('total_price')">CHF</th>
          <th :class="sortClass('status')" @click="toggleSort('status')">Status</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in sorted" :key="t.id">
          <td>{{ formatDate(t.event_date) }}</td>
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
            <label>
              <span>Kunde (optional)</span>
              <button type="button" class="link-button" @click="toggleNewCustomer">
                {{ showNewCustomer ? '× Abbrechen' : '+ Neuer Kunde' }}
              </button>
            </label>
            <select v-if="!showNewCustomer" v-model="form.customer_id">
              <option value="">Kein Kunde</option>
              <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.first_name }} {{ c.last_name }}</option>
            </select>
            <div v-else class="new-customer-block">
              <div class="form-grid-2">
                <div class="form-group">
                  <label>Anrede</label>
                  <select v-model="newCustomer.salutation">
                    <option value="">–</option>
                    <option value="Herr">Herr</option>
                    <option value="Frau">Frau</option>
                    <option value="Divers">Divers</option>
                  </select>
                </div>
                <div class="form-group">
                  <label>Vorname</label>
                  <input type="text" v-model="newCustomer.first_name" placeholder="Vorname" />
                </div>
                <div class="form-group">
                  <label>Name</label>
                  <input type="text" v-model="newCustomer.last_name" placeholder="Nachname" />
                </div>
                <div class="form-group">
                  <label>Telefon</label>
                  <input type="text" v-model="newCustomer.phone" placeholder="Telefon" />
                </div>
                <div class="form-group" style="grid-column:1 / -1">
                  <label>Email</label>
                  <input type="email" v-model="newCustomer.email" placeholder="Email" />
                </div>
              </div>
              <button
                type="button"
                class="btn btn-sm"
                :disabled="creatingCustomer || (!newCustomer.first_name && !newCustomer.last_name)"
                @click="createCustomer"
              >
                {{ creatingCustomer ? 'Anlegen …' : 'Kunde anlegen' }}
              </button>
            </div>
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
import { useSort } from '../composables/useSort.js'
import { formatDate } from '../utils/formatDate.js'
import { useAppointmentNotifications } from '../composables/useAppointmentNotifications.js'

const { markSeen } = useAppointmentNotifications()

const appointments = ref([])

const { sorted, toggleSort, sortClass } = useSort(appointments, 'event_date', 'desc')
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
  markSeen()
})

const showNewCustomer = ref(false)
const creatingCustomer = ref(false)
const emptyNewCustomer = () => ({ salutation: '', first_name: '', last_name: '', phone: '', email: '' })
const newCustomer = ref(emptyNewCustomer())

function toggleNewCustomer() {
  showNewCustomer.value = !showNewCustomer.value
  if (showNewCustomer.value) {
    newCustomer.value = emptyNewCustomer()
    form.value.customer_id = ''
  }
}

async function createCustomer() {
  creatingCustomer.value = true
  try {
    const res = await api.post('customers.php', newCustomer.value)
    customers.value = await api.get('customers.php')
    form.value.customer_id = res.id
    showNewCustomer.value = false
  } finally {
    creatingCustomer.value = false
  }
}

function openModal() {
  form.value = defaultForm()
  showNewCustomer.value = false
  newCustomer.value = emptyNewCustomer()
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  showNewCustomer.value = false
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

.form-group label {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.link-button {
  background: none;
  border: none;
  color: #2563eb;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  padding: 0;
}

.link-button:hover {
  text-decoration: underline;
}

.new-customer-block {
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 12px;
  background: #fafafa;
}
</style>
