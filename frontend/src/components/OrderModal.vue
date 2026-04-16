<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="modal">
      <h2>{{ order.id ? 'Auftrag bearbeiten' : 'Neuer Auftrag' }}</h2>

      <div class="form-group">
        <label>Datum</label>
        <input v-model="form.order_date" type="date" required>
      </div>

      <div class="form-group">
        <label>Vor Ort / Remote</label>
        <select v-model="form.location_type">
          <option value="vor_ort">Vor Ort</option>
          <option value="remote">Remote</option>
        </select>
      </div>

      <div class="form-group">
        <label>Kunde</label>
        <select v-model="form.customer_id">
          <option v-for="c in customers" :key="c.id" :value="c.id">{{ c.first_name }} {{ c.last_name }}</option>
        </select>
      </div>

      <div class="form-group">
        <label>Dienstleistungen</label>
        <div v-for="s in availableServices" :key="s.id" style="margin-bottom:4px">
          <label style="display:flex;align-items:center;gap:8px;font-weight:normal">
            <input type="checkbox" :value="s.id" v-model="selectedServiceIds">
            {{ s.name }} (CHF {{ Number(s.price).toFixed(2) }})
          </label>
        </div>
        <div style="margin-top:8px">
          <label style="font-weight:normal">
            <input type="checkbox" v-model="hasCustomService"> Custom-Dienstleistung
          </label>
          <div v-if="hasCustomService" style="display:flex;gap:8px;margin-top:4px">
            <input v-model="customServiceName" placeholder="Bezeichnung" style="flex:2">
            <input v-model.number="customServicePrice" type="number" step="0.01" placeholder="Preis" style="flex:1">
          </div>
        </div>
      </div>

      <div class="form-group">
        <label>Betrag CHF ({{ calculatedAmount.toFixed(2) }})</label>
        <input v-model.number="form.amount" type="number" step="0.01">
      </div>

      <div class="form-group">
        <label>Zuordnung</label>
        <select v-model="form.category_id">
          <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
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
import { ref, computed, onMounted, watch } from 'vue'
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

const form = ref({
  order_date: props.order.order_date || new Date().toISOString().slice(0, 10),
  customer_id: props.order.customer_id || null,
  category_id: props.order.category_id || 1,
  location_type: props.order.location_type || 'vor_ort',
  amount: props.order.amount || 0,
  notes: props.order.notes || '',
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

onMounted(async () => {
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

  if (props.order.id) {
    await api.put(`orders.php?id=${props.order.id}`, payload)
  } else {
    await api.post('orders.php', payload)
  }
  emit('saved')
}
</script>
