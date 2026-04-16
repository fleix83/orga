<template>
  <div>
    <div class="page-header">
      <h1>Aufwand</h1>
      <button class="btn btn-primary" @click="addExpense">+ Neuer Aufwand</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th>Datum</th>
          <th>Bezeichnung</th>
          <th style="text-align:right">Betrag CHF</th>
          <th>Zuordnung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="e in expenses" :key="e.id">
          <td><InlineEdit v-model="e.expense_date" @update:model-value="v => update(e, 'expense_date', v)" /></td>
          <td><InlineEdit v-model="e.description" @update:model-value="v => update(e, 'description', v)" /></td>
          <td style="text-align:right"><InlineEdit v-model="e.amount" type="number" @update:model-value="v => update(e, 'amount', v)" /></td>
          <td>
            <select :value="e.category_id" @change="update(e, 'category_id', Number($event.target.value))" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:14px">
              <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(e)">✕</button></td>
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const expenses = ref([])
const categories = ref([])
const deleteTarget = ref(null)

const total = computed(() => expenses.value.reduce((sum, e) => sum + Number(e.amount || 0), 0))

onMounted(async () => {
  const [exp, cat] = await Promise.all([api.get('expenses.php'), api.get('categories.php')])
  expenses.value = exp
  categories.value = cat
})

async function load() { expenses.value = await api.get('expenses.php') }

async function addExpense() {
  await api.post('expenses.php', { expense_date: new Date().toISOString().slice(0, 10), description: '', amount: 0, category_id: 1 })
  await load()
}

async function update(expense, field, value) {
  expense[field] = value
  await api.put(`expenses.php?id=${expense.id}`, { [field]: value })
}

function confirmDelete(e) { deleteTarget.value = e }

async function doDelete() {
  await api.del(`expenses.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
