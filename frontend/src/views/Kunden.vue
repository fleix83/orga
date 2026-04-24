<template>
  <div>
    <div class="page-header">
      <h1>Kunden</h1>
      <div style="display:flex;gap:8px">
        <input v-model="search" class="search-input" placeholder="Suchen..." @input="loadCustomers">
        <button class="btn btn-primary" @click="openNew">+ Neuer Kunde</button>
      </div>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('customer_number')" @click="toggleSort('customer_number')">Nr.</th>
          <th :class="sortClass('salutation')" @click="toggleSort('salutation')">Anrede</th>
          <th :class="sortClass('last_name')" @click="toggleSort('last_name')">Name</th>
          <th :class="sortClass('first_name')" @click="toggleSort('first_name')">Vorname</th>
          <th :class="sortClass('city')" @click="toggleSort('city')">Ort</th>
          <th :class="sortClass('phone')" @click="toggleSort('phone')">Telefon</th>
          <th :class="sortClass('email')" @click="toggleSort('email')">Email</th>
          <th style="text-align:right" :class="sortClass('total')" @click="toggleSort('total')">Total CHF</th>
          <th style="text-align:right" :class="sortClass('order_count')" @click="toggleSort('order_count')">Termine</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="c in sorted" :key="c.id" class="clickable-row" @click="openEdit(c)">
          <td>{{ c.customer_number || '–' }}</td>
          <td>{{ c.salutation || '–' }}</td>
          <td>{{ c.last_name || '–' }}</td>
          <td>{{ c.first_name || '–' }}</td>
          <td>{{ c.city || '–' }}</td>
          <td>{{ c.phone || '–' }}</td>
          <td>{{ c.email || '–' }}</td>
          <td style="text-align:right">{{ Number(c.total || 0).toFixed(2) }}</td>
          <td style="text-align:right">{{ c.order_count || 0 }}</td>
          <td @click.stop>
            <button class="btn btn-sm btn-danger" @click="confirmDelete(c)">✕</button>
          </td>
        </tr>
      </tbody>
    </table>
    </div>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`${deleteTarget?.first_name} ${deleteTarget?.last_name} wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />

    <!-- Customer Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal" style="max-width:640px">
        <h2>{{ modalCustomer.id ? 'Kunde bearbeiten' : 'Neuer Kunde' }}</h2>

        <div class="form-grid">
          <div class="form-group">
            <label>Kundennummer</label>
            <input v-model="form.customer_number" type="text" :placeholder="modalCustomer.id ? '' : (nextCustomerNumber || 'Auto')">
          </div>

          <div class="form-group">
            <label>Anrede</label>
            <select v-model="form.salutation">
              <option value="">–</option>
              <option value="Herr">Herr</option>
              <option value="Frau">Frau</option>
              <option value="Divers">Divers</option>
            </select>
          </div>

          <div class="form-group">
            <label>Vorname</label>
            <input v-model="form.first_name" type="text" placeholder="Vorname">
          </div>

          <div class="form-group">
            <label>Name</label>
            <input v-model="form.last_name" type="text" placeholder="Nachname">
          </div>

          <div class="form-group">
            <label>Ort</label>
            <input v-model="form.city" type="text" placeholder="Ort">
          </div>

          <div class="form-group">
            <label>PLZ</label>
            <input v-model="form.zip" type="text" placeholder="PLZ">
          </div>

          <div class="form-group">
            <label>Strasse</label>
            <input v-model="form.street" type="text" placeholder="Strasse">
          </div>

          <div class="form-group">
            <label>Telefon</label>
            <input v-model="form.phone" type="text" placeholder="Telefon">
          </div>

          <div class="form-group">
            <label>Email</label>
            <input v-model="form.email" type="email" placeholder="Email">
          </div>

          <div class="form-group">
            <label>Nationalität</label>
            <input v-model="form.nationality" type="text" placeholder="Nationalität">
          </div>
        </div>

        <div class="form-group" style="margin-top:4px">
          <label>Anmerkung</label>
          <textarea v-model="form.notes" rows="3" placeholder="Anmerkungen..."></textarea>
        </div>

        <div v-if="modalCustomer.id" class="customer-stats">
          <div><span class="stat-label">Total CHF</span><span class="stat-value">{{ Number(modalCustomer.total || 0).toFixed(2) }}</span></div>
          <div><span class="stat-label">Termine</span><span class="stat-value">{{ modalCustomer.order_count || 0 }}</span></div>
          <div><span class="stat-label">Gesamtzeit</span><span class="stat-value">{{ formatDuration(modalCustomer.total_duration) }}</span></div>
        </div>

        <div class="form-actions">
          <button class="btn" @click="closeModal">Abbrechen</button>
          <button class="btn btn-primary" @click="saveModal">Speichern</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { useSort } from '../composables/useSort.js'

function formatDuration(mins) {
  const n = Number(mins || 0)
  if (n <= 0) return '0 Min'
  const h = Math.floor(n / 60)
  const m = n % 60
  if (h === 0) return `${m} Min`
  if (m === 0) return `${h} h`
  return `${h} h ${m} Min`
}

const customers = ref([])

const { sorted, toggleSort, sortClass } = useSort(customers, 'last_name', 'asc')
const search = ref('')
const deleteTarget = ref(null)

// Modal state
const showModal = ref(false)
const modalCustomer = ref({})
const form = ref(emptyForm())

function emptyForm() {
  return {
    customer_number: '',
    salutation: '',
    first_name: '',
    last_name: '',
    street: '',
    zip: '',
    city: '',
    phone: '',
    email: '',
    nationality: '',
    notes: '',
  }
}

const nextCustomerNumber = ref('')

onMounted(loadCustomers)

async function loadCustomers() {
  const query = search.value ? `?search=${encodeURIComponent(search.value)}` : ''
  customers.value = await api.get(`customers.php${query}`)
}

async function openNew() {
  modalCustomer.value = {}
  form.value = emptyForm()
  showModal.value = true
  try {
    const res = await api.get('customers.php?next_number=1')
    nextCustomerNumber.value = res.next_number || ''
  } catch {
    nextCustomerNumber.value = ''
  }
}

function openEdit(customer) {
  modalCustomer.value = customer
  form.value = {
    customer_number: customer.customer_number || '',
    salutation: customer.salutation || '',
    first_name: customer.first_name || '',
    last_name: customer.last_name || '',
    street: customer.street || '',
    zip: customer.zip || '',
    city: customer.city || '',
    phone: customer.phone || '',
    email: customer.email || '',
    nationality: customer.nationality || '',
    notes: customer.notes || '',
  }
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  modalCustomer.value = {}
}

async function saveModal() {
  if (modalCustomer.value.id) {
    await api.put(`customers.php?id=${modalCustomer.value.id}`, form.value)
  } else {
    await api.post('customers.php', form.value)
  }
  closeModal()
  await loadCustomers()
}

function confirmDelete(customer) {
  deleteTarget.value = customer
}

async function doDelete() {
  await api.del(`customers.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await loadCustomers()
}
</script>

<style scoped>
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 16px;
}

.customer-stats {
  display: flex;
  gap: 24px;
  flex-wrap: wrap;
  padding: 14px 16px;
  background: #fafafa;
  border-radius: 8px;
  margin-top: 16px;
}

.customer-stats > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.stat-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  color: #9ca3af;
  font-weight: 600;
}

.stat-value {
  font-size: 15px;
  font-weight: 600;
  color: #111827;
}
</style>
