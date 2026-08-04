<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal" style="max-width:640px">
      <h2>{{ customerId ? 'Kunde bearbeiten' : 'Neuer Kunde' }}</h2>

      <div class="form-grid">
        <div class="form-group">
          <label>Kundennummer</label>
          <input v-model="form.customer_number" type="text" :placeholder="customerId ? '' : (nextCustomerNumber || 'Auto')">
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

      <div v-if="customerId" class="customer-stats">
        <div><span class="stat-label">Total CHF</span><span class="stat-value">{{ Number(customer.total || 0).toFixed(2) }}</span></div>
        <div><span class="stat-label">Termine</span><span class="stat-value">{{ customer.order_count || 0 }}</span></div>
        <div><span class="stat-label">Gesamtzeit</span><span class="stat-value">{{ formatDuration(customer.total_duration) }}</span></div>
      </div>

      <div class="form-actions">
        <button class="btn" @click="$emit('close')">Abbrechen</button>
        <button class="btn btn-primary" @click="save">Speichern</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'

const props = defineProps({
  // null/undefined opens an empty form for a new customer
  customerId: { type: [Number, String], default: null },
})

const emit = defineEmits(['close', 'saved'])

const customer = ref({})
const nextCustomerNumber = ref('')
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

function formatDuration(mins) {
  const n = Number(mins || 0)
  if (n <= 0) return '0 Min'
  const h = Math.floor(n / 60)
  const m = n % 60
  if (h === 0) return `${m} Min`
  if (m === 0) return `${h} h`
  return `${h} h ${m} Min`
}

onMounted(async () => {
  if (props.customerId) {
    customer.value = await api.get(`customers.php?id=${props.customerId}`)
    for (const key of Object.keys(form.value)) {
      form.value[key] = customer.value[key] || ''
    }
  } else {
    try {
      const res = await api.get('customers.php?next_number=1')
      nextCustomerNumber.value = res.next_number || ''
    } catch {
      nextCustomerNumber.value = ''
    }
  }
})

async function save() {
  if (props.customerId) {
    await api.put(`customers.php?id=${props.customerId}`, form.value)
  } else {
    await api.post('customers.php', form.value)
  }
  emit('saved')
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
