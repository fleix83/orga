<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <h2 class="modal-title">
        {{ currentId ? 'Buchung bearbeiten' : 'Neue Buchung' }}
        <button
          type="button"
          :class="['status-dot', statusClass]"
          :title="statusLabel"
          @click="cycleStatus"
        ></button>
        <span
          v-if="justCreated"
          class="new-indicator"
          title="Neu erstellte Buchung — noch nicht gespeichert"
        >*</span>
        <button
          v-else-if="currentId"
          type="button"
          class="new-from-link"
          @click="saveAsNew"
        >New from Booking</button>
      </h2>

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
          <div class="multi-select" ref="customerRef">
            <button
              type="button"
              :class="['multi-select-trigger', { invalid: saveError && !form.customer_id }]"
              @click="toggleCustomerDropdown"
            >
              <span>{{ selectedCustomerLabel }}</span>
              <span class="chevron">▾</span>
            </button>
            <div v-if="customerOpen" class="multi-select-panel">
              <div class="dropdown-search">
                <input
                  ref="customerSearchRef"
                  v-model="customerSearch"
                  type="text"
                  placeholder="Kunde suchen..."
                >
              </div>
              <button
                v-for="c in filteredCustomers"
                :key="c.id"
                type="button"
                :class="['dropdown-option', { selected: Number(c.id) === Number(form.customer_id) }]"
                @click="selectCustomer(c)"
              >{{ c.first_name }} {{ c.last_name }}</button>
              <div v-if="!filteredCustomers.length" class="dropdown-empty">Keine Kunden gefunden</div>
            </div>
          </div>
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

      <div v-if="saveError" class="save-error">{{ saveError }}</div>

      <div class="form-actions">
        <button class="btn" @click="$emit('close')">Abbrechen</button>
        <button class="btn btn-primary" @click="save">Speichern</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick, onMounted, onBeforeUnmount, watch } from 'vue'
import { api } from '../api.js'

const props = defineProps({
  order: { type: Object, default: () => ({}) },
})

const emit = defineEmits(['close', 'saved', 'created'])

// Tracks which booking the modal is editing; changes when "New from Booking"
// creates a fresh record that the modal then continues to edit.
const currentId = ref(props.order.id || null)

// True right after "New from Booking" — shows the asterisk instead of the
// link so the fresh duplicate is distinguishable; cleared on Speichern.
const justCreated = ref(false)

const customers = ref([])
const availableServices = ref([])
const categories = ref([])
const selectedServiceIds = ref([])
const hasCustomService = ref(false)
const customServiceName = ref('')
const customServicePrice = ref(0)

const dropdownOpen = ref(false)
const dropdownRef = ref(null)

const customerOpen = ref(false)
const customerRef = ref(null)
const customerSearchRef = ref(null)
const customerSearch = ref('')

const form = ref({
  order_date: props.order.order_date || new Date().toISOString().slice(0, 10),
  order_time: normalizeTime(props.order.order_time),
  customer_id: props.order.customer_id || null,
  category_id: props.order.category_id || 1,
  location_type: props.order.location_type || 'vor_ort',
  status: props.order.status || null,
  amount: props.order.amount || 0,
  duration_minutes: props.order.duration_minutes ?? null,
  notes: props.order.notes || '',
})

// Status dot: grey = automatisch (nach Datum), blau = manuell pendent, grün = erledigt
const statusClass = computed(() => form.value.status || 'auto')

const statusLabel = computed(() => ({
  pending: 'Status: Pendent (manuell)',
  done: 'Status: Erledigt',
}[form.value.status] || 'Status: Automatisch (nach Datum)'))

function cycleStatus() {
  const next = { auto: 'pending', pending: 'done', done: 'auto' }
  const val = next[form.value.status || 'auto']
  form.value.status = val === 'auto' ? null : val
}

// MySQL returns TIME as "HH:MM:SS"; <input type="time"> expects "HH:MM".
function normalizeTime(t) {
  if (!t) return ''
  return typeof t === 'string' && t.length >= 5 ? t.slice(0, 5) : t
}

const selectedCustomerLabel = computed(() => {
  const c = customers.value.find(x => Number(x.id) === Number(form.value.customer_id))
  return c ? `${c.first_name} ${c.last_name}`.trim() : 'Auswählen...'
})

const filteredCustomers = computed(() => {
  const q = customerSearch.value.trim().toLowerCase()
  if (!q) return customers.value
  return customers.value.filter(c =>
    `${c.first_name} ${c.last_name}`.toLowerCase().includes(q)
  )
})

function toggleCustomerDropdown() {
  customerOpen.value = !customerOpen.value
  if (customerOpen.value) {
    customerSearch.value = ''
    nextTick(() => customerSearchRef.value?.focus())
  }
}

function selectCustomer(customer) {
  form.value.customer_id = customer.id
  customerOpen.value = false
  saveError.value = ''
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
  if (customerOpen.value && customerRef.value && !customerRef.value.contains(e.target)) {
    customerOpen.value = false
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

const saveError = ref('')

function buildPayload() {
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
  return payload
}

async function save() {
  if (!form.value.customer_id) {
    saveError.value = 'Bitte einen Kunden auswählen.'
    return
  }
  saveError.value = ''

  try {
    const payload = buildPayload()
    if (currentId.value) {
      await api.put(`orders.php?id=${currentId.value}`, payload)
    } else {
      await api.post('orders.php', payload)
    }
    justCreated.value = false
    emit('saved')
  } catch (e) {
    saveError.value = e.message || 'Speichern fehlgeschlagen.'
  }
}

// Creates a NEW booking from the current form data (the opened booking stays
// untouched) and keeps the modal open, now editing the new record.
async function saveAsNew() {
  if (!form.value.customer_id) {
    saveError.value = 'Bitte einen Kunden auswählen.'
    return
  }
  saveError.value = ''

  try {
    const res = await api.post('orders.php', buildPayload())
    currentId.value = res.id
    justCreated.value = true
    emit('created')
  } catch (e) {
    saveError.value = e.message || 'Speichern fehlgeschlagen.'
  }
}
</script>

<style scoped>
.modal-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

/* Status dot: grey = automatisch, blau = pendent (manuell), grün = erledigt */
.status-dot {
  appearance: none;
  border: none;
  padding: 0;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #d1d5db;
  cursor: pointer;
  flex-shrink: 0;
  transition: background 0.12s ease, box-shadow 0.12s ease;
}

.status-dot:hover { box-shadow: 0 0 0 4px rgba(17, 24, 39, 0.06); }

.status-dot.pending { background: #728fef; }
.status-dot.pending:hover { box-shadow: 0 0 0 4px rgba(114, 143, 239, 0.2); }

.status-dot.done { background: #10b981; }
.status-dot.done:hover { box-shadow: 0 0 0 4px rgba(16, 185, 129, 0.15); }

/* Quiet text link, pushed to the far right of the title row */
.new-from-link {
  appearance: none;
  border: none;
  background: transparent;
  margin-left: auto;
  padding: 2px 0;
  font: inherit;
  font-size: 12px;
  font-weight: 600;
  color: #728fef;
  cursor: pointer;
  white-space: nowrap;
}

.new-from-link:hover { color: #4c6ce0; text-decoration: underline; }

/* Marks a freshly duplicated booking: big blue asterisk pinned to the
   modal's top-right corner, on the title line / hamburger column */
.modal { position: relative; }

.new-indicator {
  position: absolute;
  top: 28px;
  right: 24px;
  font-size: 45px;
  line-height: 1;
  color: #728fef;
  cursor: default;
}

@media (max-width: 768px) {
  /* Full-screen modal: title starts below the fixed hamburger (top 72px) */
  .new-indicator { top: 64px; }
}

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

.multi-select-trigger.invalid,
.multi-select-trigger.invalid:hover { border-color: #dc2626; }

.save-error {
  margin-top: 12px;
  font-size: 13px;
  color: #dc2626;
}

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

/* Search box pinned above the option list */
.dropdown-search {
  position: sticky;
  top: -6px;
  background: #fff;
  padding: 2px 2px 8px;
  margin: -2px -2px 2px;
  border-bottom: 1px solid #f3f4f6;
}

.dropdown-search input {
  padding: 8px 12px;
  font-size: 14px;
}

.dropdown-option {
  display: block;
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

.dropdown-option:hover { background: #f9fafb; }

.dropdown-option.selected {
  background: #f3f4f6;
  font-weight: 600;
}

.dropdown-empty {
  padding: 10px;
  font-size: 13px;
  color: #9ca3af;
  text-align: center;
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
