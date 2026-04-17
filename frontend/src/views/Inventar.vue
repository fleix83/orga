<template>
  <div>
    <div class="page-header">
      <h1>Inventar</h1>
      <button class="btn btn-primary" @click="openNew">+ Neues Inventar</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('purchase_date')" @click="toggleSort('purchase_date')">Kaufdatum</th>
          <th :class="sortClass('name')" @click="toggleSort('name')">Bezeichnung</th>
          <th style="text-align:right" :class="sortClass('value')" @click="toggleSort('value')">Wert CHF</th>
          <th :class="sortClass('owner')" @click="toggleSort('owner')">Zuordnung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in sorted" :key="item.id" class="clickable-row" @click="openEdit(item)">
          <td>{{ formatDate(item.purchase_date) }}</td>
          <td>{{ item.name }}</td>
          <td style="text-align:right">{{ Number(item.value || 0).toFixed(2) }}</td>
          <td>{{ item.owner === 'felix' ? 'Felix' : 'Araceli' }}</td>
          <td @click.stop>
            <button class="btn btn-sm btn-danger" @click="confirmDelete(item)">✕</button>
          </td>
        </tr>
        <tr class="totals-row">
          <td></td>
          <td>Total</td>
          <td style="text-align:right">{{ totalAll.toFixed(2) }}</td>
          <td colspan="2"></td>
        </tr>
        <tr>
          <td></td>
          <td style="color:#6b7280">Felix</td>
          <td style="text-align:right;color:#6b7280">{{ totalFelix.toFixed(2) }}</td>
          <td colspan="2"></td>
        </tr>
        <tr>
          <td></td>
          <td style="color:#6b7280">Araceli</td>
          <td style="text-align:right;color:#6b7280">{{ totalAraceli.toFixed(2) }}</td>
          <td colspan="2"></td>
        </tr>
      </tbody>
    </table>
    </div>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`'${deleteTarget?.name}' wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />

    <!-- Inventory Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal" style="max-width:520px">
        <h2>{{ modalItem.id ? 'Inventar bearbeiten' : 'Neues Inventar' }}</h2>

        <div class="form-group">
          <label>Bezeichnung</label>
          <input v-model="form.name" type="text" placeholder="Bezeichnung">
        </div>

        <div class="form-grid">
          <div class="form-group">
            <label>Kaufdatum</label>
            <input v-model="form.purchase_date" type="date">
          </div>
          <div class="form-group">
            <label>Wert CHF</label>
            <input v-model.number="form.value" type="number" step="0.01">
          </div>
        </div>

        <div class="form-group">
          <label>Zuordnung</label>
          <select v-model="form.owner">
            <option value="felix">Felix</option>
            <option value="araceli">Araceli</option>
          </select>
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
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { useSort } from '../composables/useSort.js'
import { formatDate } from '../utils/formatDate.js'

const items = ref([])

const { sorted, toggleSort, sortClass } = useSort(items, 'purchase_date', 'desc')
const deleteTarget = ref(null)

const showModal = ref(false)
const modalItem = ref({})
const form = ref(emptyForm())

function emptyForm() {
  return { name: '', value: 0, purchase_date: null, owner: 'felix' }
}

const totalAll = computed(() => items.value.reduce((sum, i) => sum + Number(i.value || 0), 0))
const totalFelix = computed(() => items.value.filter(i => i.owner === 'felix').reduce((sum, i) => sum + Number(i.value || 0), 0))
const totalAraceli = computed(() => items.value.filter(i => i.owner === 'araceli').reduce((sum, i) => sum + Number(i.value || 0), 0))

onMounted(load)

async function load() { items.value = await api.get('inventory.php') }

function openNew() {
  modalItem.value = {}
  form.value = emptyForm()
  showModal.value = true
}

function openEdit(item) {
  modalItem.value = item
  form.value = {
    name: item.name || '',
    value: Number(item.value || 0),
    purchase_date: item.purchase_date ? String(item.purchase_date).slice(0, 10) : null,
    owner: item.owner || 'felix',
  }
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  modalItem.value = {}
}

async function saveModal() {
  const payload = {
    name: form.value.name,
    value: form.value.value,
    purchase_date: form.value.purchase_date || null,
    owner: form.value.owner,
  }
  if (modalItem.value.id) {
    await api.put(`inventory.php?id=${modalItem.value.id}`, payload)
  } else {
    await api.post('inventory.php', payload)
  }
  closeModal()
  await load()
}

function confirmDelete(item) { deleteTarget.value = item }

async function doDelete() {
  await api.del(`inventory.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>

<style scoped>
.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 16px;
}
</style>
