<template>
  <div>
    <div class="page-header">
      <h1>Geschäftszahlen</h1>
      <div style="display:flex;gap:8px;align-items:center">
        <button class="btn btn-sm" @click="prevPeriod">←</button>
        <select v-model="selectedYear" @change="load" style="width:auto">
          <option v-for="y in years" :key="y" :value="y">{{ y }}</option>
        </select>
        <select v-model="selectedMonth" @change="load" style="width:auto">
          <option :value="null">Ganzes Jahr</option>
          <option v-for="m in 12" :key="m" :value="m">{{ monthNames[m - 1] }}</option>
        </select>
        <button class="btn btn-sm" @click="nextPeriod">→</button>
      </div>
    </div>

    <div style="display:flex;gap:8px;margin-bottom:20px">
      <a :href="exportUrl('csv')" class="btn btn-sm">CSV Export</a>
      <a :href="exportUrl('pdf')" class="btn btn-sm">PDF Export</a>
    </div>

    <template v-if="selectedMonth">
      <h3 style="margin-bottom:12px">Einnahmen</h3>
      <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th :class="sortClassOrders('order_date')" @click="toggleSortOrders('order_date')">Datum</th>
            <th :class="sortClassOrders('customer_first_name')" @click="toggleSortOrders('customer_first_name')">Kunde</th>
            <th :class="sortClassOrders('service_names')" @click="toggleSortOrders('service_names')">Dienstleistung</th>
            <th :class="sortClassOrders('category_name')" @click="toggleSortOrders('category_name')">Zuordnung</th>
            <th style="text-align:right" :class="sortClassOrders('amount')" @click="toggleSortOrders('amount')">CHF</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="o in sortedOrders" :key="o.id">
            <td>{{ formatDate(o.order_date) }}</td>
            <td>{{ o.customer_first_name }} {{ o.customer_last_name }}</td>
            <td>{{ o.service_names }}</td>
            <td>{{ o.category_name }}</td>
            <td style="text-align:right">{{ Number(o.amount).toFixed(2) }}</td>
          </tr>
          <tr class="totals-row"><td colspan="4">Total Einnahmen</td><td style="text-align:right">{{ Number(report.total_income || 0).toFixed(2) }}</td></tr>
        </tbody>
      </table>
      </div>

      <h3 style="margin:20px 0 12px">Aufwände</h3>
      <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th :class="sortClassExpenses('expense_date')" @click="toggleSortExpenses('expense_date')">Datum</th>
            <th :class="sortClassExpenses('description')" @click="toggleSortExpenses('description')">Bezeichnung</th>
            <th :class="sortClassExpenses('category_name')" @click="toggleSortExpenses('category_name')">Zuordnung</th>
            <th style="text-align:right" :class="sortClassExpenses('amount')" @click="toggleSortExpenses('amount')">CHF</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="e in sortedExpenses" :key="e.id">
            <td>{{ formatDate(e.expense_date) }}</td>
            <td>{{ e.description }}</td>
            <td>{{ e.category_name }}</td>
            <td style="text-align:right">{{ Number(e.amount).toFixed(2) }}</td>
          </tr>
          <tr class="totals-row"><td colspan="3">Total Aufwände</td><td style="text-align:right">{{ Number(report.total_expenses || 0).toFixed(2) }}</td></tr>
        </tbody>
      </table>
      </div>

      <div class="table-wrap">
      <table style="margin-top:20px">
        <tbody>
          <tr class="totals-row">
            <td>Bilanz</td>
            <td style="text-align:right;font-size:16px">CHF {{ Number(report.balance || 0).toFixed(2) }}</td>
          </tr>
        </tbody>
      </table>
      </div>
    </template>

    <template v-else>
      <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Monat</th><th style="text-align:right">Einnahmen</th><th style="text-align:right">Aufwände</th><th style="text-align:right">Bilanz</th><th style="text-align:right">Aufträge</th></tr>
        </thead>
        <tbody>
          <tr v-for="m in report.months" :key="m.month" style="cursor:pointer" @click="selectedMonth = m.month; load()">
            <td>{{ monthNames[m.month - 1] }}</td>
            <td style="text-align:right">{{ Number(m.income).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(m.expenses).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(m.balance).toFixed(2) }}</td>
            <td style="text-align:right">{{ m.order_count }}</td>
          </tr>
          <tr class="totals-row">
            <td>Total</td>
            <td style="text-align:right">{{ Number(report.total_income || 0).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(report.total_expenses || 0).toFixed(2) }}</td>
            <td style="text-align:right">{{ Number(report.balance || 0).toFixed(2) }}</td>
            <td></td>
          </tr>
        </tbody>
      </table>
      </div>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import { useSort } from '../composables/useSort.js'
import { formatDate } from '../utils/formatDate.js'

const monthNames = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember']
const currentYear = new Date().getFullYear()
const years = Array.from({ length: 5 }, (_, i) => currentYear - 2 + i)

const selectedYear = ref(currentYear)
const selectedMonth = ref(null)
const report = ref({})

const reportOrders = computed(() => report.value.orders || [])
const reportExpenses = computed(() => report.value.expenses || [])

const { sorted: sortedOrders, toggleSort: toggleSortOrders, sortClass: sortClassOrders } = useSort(reportOrders, 'order_date', 'asc')
const { sorted: sortedExpenses, toggleSort: toggleSortExpenses, sortClass: sortClassExpenses } = useSort(reportExpenses, 'expense_date', 'asc')

onMounted(load)

async function load() {
  const params = selectedMonth.value
    ? `?month=${selectedMonth.value}&year=${selectedYear.value}`
    : `?year=${selectedYear.value}`
  report.value = await api.get(`reports.php${params}`)
}

function exportUrl(type) {
  const base = import.meta.env.DEV ? '/api' : '/orga/api'
  const params = selectedMonth.value
    ? `type=${type}&month=${selectedMonth.value}&year=${selectedYear.value}`
    : `type=${type}&year=${selectedYear.value}`
  return `${base}/export.php?${params}`
}

function prevPeriod() {
  if (selectedMonth.value) {
    selectedMonth.value--
    if (selectedMonth.value < 1) { selectedMonth.value = 12; selectedYear.value-- }
  } else {
    selectedYear.value--
  }
  load()
}

function nextPeriod() {
  if (selectedMonth.value) {
    selectedMonth.value++
    if (selectedMonth.value > 12) { selectedMonth.value = 1; selectedYear.value++ }
  } else {
    selectedYear.value++
  }
  load()
}
</script>
