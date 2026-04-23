<template>
  <div>
    <div class="page-header">
      <h1>Aufwand</h1>
      <button class="btn btn-primary" @click="openNew">+ Neuer Aufwand</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('expense_date')" @click="toggleSort('expense_date')">Datum</th>
          <th :class="sortClass('description')" @click="toggleSort('description')">Bezeichnung</th>
          <th style="text-align:right" :class="sortClass('amount')" @click="toggleSort('amount')">Betrag CHF</th>
          <th :class="sortClass('category_name')" @click="toggleSort('category_name')">Zuordnung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="e in sorted" :key="e.id" class="clickable-row" @click="openEdit(e)">
          <td>{{ formatDate(e.expense_date) }}</td>
          <td>{{ e.description || '–' }}</td>
          <td style="text-align:right">{{ Number(e.amount || 0).toFixed(2) }}</td>
          <td>{{ e.category_name || '–' }}</td>
          <td @click.stop>
            <button class="btn btn-sm btn-danger" @click="confirmDelete(e)">✕</button>
          </td>
        </tr>
        <tr class="totals-row">
          <td colspan="2">Total</td>
          <td style="text-align:right">{{ total.toFixed(2) }}</td>
          <td colspan="2"></td>
        </tr>
      </tbody>
    </table>
    </div>

    <ConfirmDialog
      :visible="!!deleteTarget"
      message="Aufwand wirklich löschen?"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />

    <!-- Expense Modal -->
    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal" style="max-width:520px">
        <h2>{{ modalExpense.id ? 'Aufwand bearbeiten' : 'Neuer Aufwand' }}</h2>

        <div class="form-grid">
          <div class="form-group">
            <label>Datum</label>
            <input v-model="form.expense_date" type="date">
          </div>
          <div class="form-group">
            <label>Betrag CHF</label>
            <input v-model.number="form.amount" type="number" step="0.01">
          </div>
        </div>

        <div class="form-group">
          <label>Bezeichnung</label>
          <input v-model="form.description" type="text" placeholder="Bezeichnung">
        </div>

        <div class="form-group">
          <label>Zuordnung</label>
          <select v-model="form.category_id">
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
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

const expenses = ref([])
const categories = ref([])
const deleteTarget = ref(null)

const { sorted, toggleSort, sortClass } = useSort(expenses, 'expense_date', 'desc')

const showModal = ref(false)
const modalExpense = ref({})
const form = ref(emptyForm())

function emptyForm() {
  return {
    expense_date: new Date().toISOString().slice(0, 10),
    description: '',
    amount: 0,
    category_id: 1,
  }
}

const total = computed(() => expenses.value.reduce((sum, e) => sum + Number(e.amount || 0), 0))

onMounted(async () => {
  const [exp, cat] = await Promise.all([api.get('expenses.php'), api.get('categories.php')])
  expenses.value = exp
  categories.value = cat
})

async function load() { expenses.value = await api.get('expenses.php') }

function openNew() {
  modalExpense.value = {}
  form.value = emptyForm()
  if (categories.value.length) form.value.category_id = categories.value[0].id
  showModal.value = true
}

function openEdit(expense) {
  modalExpense.value = expense
  form.value = {
    expense_date: expense.expense_date ? String(expense.expense_date).slice(0, 10) : '',
    description: expense.description || '',
    amount: Number(expense.amount || 0),
    category_id: expense.category_id,
  }
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  modalExpense.value = {}
}

async function saveModal() {
  const payload = {
    expense_date: form.value.expense_date,
    description: form.value.description,
    amount: form.value.amount,
    category_id: form.value.category_id,
  }
  if (modalExpense.value.id) {
    await api.put(`expenses.php?id=${modalExpense.value.id}`, payload)
  } else {
    await api.post('expenses.php', payload)
  }
  closeModal()
  await load()
}

function confirmDelete(e) { deleteTarget.value = e }

async function doDelete() {
  await api.del(`expenses.php?id=${deleteTarget.value.id}`)
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
