<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <h2>{{ order.id ? 'Buchung bearbeiten' : 'Neue Buchung' }}</h2>

      <div class="modal-grid modal-grid-3">
        <div class="form-group">
          <label>Datum</label>
          <input v-model="form.order_date" type="date" required>
        </div>
        <div class="form-group">
          <label>Uhrzeit</label>
          <input v-model="form.order_time" type="time">
        </div>
        <div class="form-group">
          <label>Ort</label>
          <div class="seg-switch" role="tablist">
            <button
              type="button"
              role="tab"
              :aria-selected="form.location_type === 'vor_ort'"
              :class="['seg-option', { active: form.location_type === 'vor_ort' }]"
              @click="form.location_type = 'vor_ort'"
            >Vor Ort</button>
            <button
              type="button"
              role="tab"
              :aria-selected="form.location_type === 'remote'"
              :class="['seg-option', { active: form.location_type === 'remote' }]"
              @click="form.location_type = 'remote'"
            >Remote</button>
          </div>
        </div>
      </div>

      <div class="modal-grid">
        <div class="form-group">
          <label>Kunde</label>
          <select v-model="form.customer_id">
            <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.first_name }} {{ c.last_name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>Zuordnung</label>
          <select v-model="form.category_id">
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
      </div>

      <div class="form-group">
        <label>Dienstleistungen</label>
        <div class="multi-select" ref="dropdownRef">
          <button type="button" class="multi-select-trigger" @click="dropdownOpen = !dropdownOpen">
            <span>{{ selectedLabel }}</span>
            <span class="chevron">▾</span>
          </button>
          <div v-if="dropdownOpen" class="multi-select-panel">
            <label v-for="s in selectableServices" :key="s.id" class="multi-select-option">
              <input type="checkbox" :value="s.id" v-model="selectedServiceIds">
              <span class="option-name">{{ s.name }}</span>
              <span class="option-price">CHF {{ Number(s.price).toFixed(2) }}</span>
            </label>
            <label class="multi-select-option">
              <input type="checkbox" v-model="hasCustomService">
              <span class="option-name">Custom-Dienstleistung</span>
            </label>
          </div>
        </div>
        <div v-if="hasCustomService" class="custom-service">
          <input v-model="customServiceName" placeholder="Bezeichnung" class="custom-name">
          <input v-model.number="customServicePrice" type="number" step="0.01" placeholder="Preis" class="custom-price">
        </div>
      </div>

      <div class="modal-grid">
        <div class="form-group">
          <label>Betrag CHF ({{ calculatedAmount.toFixed(2) }})</label>
          <input v-model.number="form.amount" type="number" step="0.01">
        </div>
        <div class="form-group">
          <label>Zeit (Min.)</label>
          <input v-model.number="form.duration_minutes" type="number" step="5" min="0" placeholder="0">
        </div>
      </div>

      <div class="form-group">
        <label>Anmerkungen</label>
        <textarea v-model="form.notes" rows="3"></textarea>
      </div>

      <div class="form-actions">
        <button class="btn" @click="$emit('close')">Abbrechen</button>
        <button class="btn btn-primary" @click="save">Speichern</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { api } from '../api.js'

const props = defineProps({
  order: { type: Object, default: () => ({}) },
})

const emit = defineEmits(['close', 'saved'])

const customers = ref([])
const availableServices = ref([])
const categories = ref([])
const selectedServiceIds = ref([])
const hasCustomService = ref(false)
const customServiceName = ref('')
const customServicePrice = ref(0)

const dropdownOpen = ref(false)
const dropdownRef = ref(null)

const form = ref({
  order_date: props.order.order_date || new Date().toISOString().slice(0, 10),
  order_time: normalizeTime(props.order.order_time),
  customer_id: props.order.customer_id || null,
  category_id: props.order.category_id || 1,
  location_type: props.order.location_type || 'vor_ort',
  amount: props.order.amount || 0,
  duration_minutes: props.order.duration_minutes ?? null,
  notes: props.order.notes || '',
})

// MySQL returns TIME as "HH:MM:SS"; <input type="time"> expects "HH:MM".
function normalizeTime(t) {
  if (!t) return ''
  return typeof t === 'string' && t.length >= 5 ? t.slice(0, 5) : t
}

const selectableServices = computed(() =>
  availableServices.value.filter(s => s.name && s.name.trim())
)

const selectedLabel = computed(() => {
  const parts = []
  for (const id of selectedServiceIds.value) {
    const svc = selectableServices.value.find(s => s.id === id)
    if (svc) parts.push(svc.name)
  }
  if (hasCustomService.value) parts.push('Custom')
  return parts.length ? parts.join(', ') : 'Auswählen...'
})

const calculatedAmount = computed(() => {
  let total = 0
  for (const id of selectedServiceIds.value) {
    const svc = availableServices.value.find(s => s.id === id)
    if (svc) total += Number(svc.price)
  }
  if (hasCustomService.value) total += Number(customServicePrice.value) || 0
  return total
})

watch(calculatedAmount, (val) => {
  form.value.amount = val
})

function handleClickOutside(e) {
  if (dropdownOpen.value && dropdownRef.value && !dropdownRef.value.contains(e.target)) {
    dropdownOpen.value = false
  }
}

onMounted(async () => {
  document.addEventListener('click', handleClickOutside)

  const [c, s, cat] = await Promise.all([
    api.get('customers.php'),
    api.get('services.php'),
    api.get('categories.php'),
  ])
  customers.value = c
  availableServices.value = s.filter(x => x.active == 1)
  categories.value = cat

  if (props.order.id) {
    const full = await api.get(`orders.php?id=${props.order.id}`)
    if (full.services) {
      for (const os of full.services) {
        if (os.service_id) {
          selectedServiceIds.value.push(os.service_id)
        } else if (os.custom_name) {
          hasCustomService.value = true
          customServiceName.value = os.custom_name
          customServicePrice.value = Number(os.price)
        }
      }
    }
  }
})

onBeforeUnmount(() => {
  document.removeEventListener('click', handleClickOutside)
})

async function save() {
  const services = []
  for (const id of selectedServiceIds.value) {
    const svc = availableServices.value.find(s => s.id === id)
    services.push({ service_id: id, price: Number(svc.price) })
  }
  if (hasCustomService.value && customServiceName.value) {
    services.push({ service_id: null, custom_name: customServiceName.value, price: Number(customServicePrice.value) || 0 })
  }

  const payload = { ...form.value, services }
  if (!payload.order_time) payload.order_time = null

  if (props.order.id) {
    await api.put(`orders.php?id=${props.order.id}`, payload)
  } else {
    await api.post('orders.php', payload)
  }
  emit('saved')
}
</script>

<style scoped>
.modal-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

.modal-grid-3 {
  grid-template-columns: 1fr 1fr 1fr;
}

@media (max-width: 560px) {
  .modal-grid-3 { grid-template-columns: 1fr; }
}

/* Segmented switch — two equal-width tabs */
.seg-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
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
  padding: 7px 10px;
  border-radius: 6px;
  font: inherit;
  font-size: 13px;
  font-weight: 500;
  color: #6b7280;
  cursor: pointer;
  transition: background 0.12s ease, color 0.12s ease, box-shadow 0.12s ease;
  white-space: nowrap;
}

.seg-option:hover { color: #111827; }

.seg-option.active {
  background: #fff;
  color: #111827;
  box-shadow: 0 1px 2px rgba(17, 24, 39, 0.08);
}

.multi-select {
  position: relative;
}

.multi-select-trigger {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: #fff;
  font-size: 14px;
  font-family: inherit;
  color: #111827;
  cursor: pointer;
  text-align: left;
}

.multi-select-trigger:hover { border-color: #d1d5db; }

.multi-select-trigger span:first-child {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  padding-right: 8px;
}

.chevron {
  color: #6b7280;
  font-size: 11px;
  flex-shrink: 0;
}

.multi-select-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08);
  z-index: 10;
  max-height: 280px;
  overflow-y: auto;
  padding: 6px;
}

.multi-select-option {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 10px;
  border-radius: 6px;
  cursor: pointer;
  font-weight: normal;
  font-size: 14px;
  color: #111827;
  text-transform: none;
  letter-spacing: 0;
  margin: 0;
}

.multi-select-option:hover { background: #f9fafb; }

.multi-select-option input[type="checkbox"] {
  width: auto;
  margin: 0;
  flex-shrink: 0;
}

.option-name { flex: 1; }

.option-price {
  color: #6b7280;
  font-size: 13px;
}

.custom-service {
  display: flex;
  gap: 8px;
  margin-top: 8px;
}

.custom-name { flex: 2; }
.custom-price { flex: 1; }
</style>
