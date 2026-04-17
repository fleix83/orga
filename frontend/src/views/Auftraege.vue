<template>
  <div>
    <div class="page-header">
      <h1>Aufträge</h1>
      <button class="btn btn-primary" @click="showModal = true; editOrder = {}">+ Neuer Auftrag</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('order_date')" @click="toggleSort('order_date')">Datum</th>
          <th :class="sortClass('order_number')" @click="toggleSort('order_number')">Nr.</th>
          <th :class="sortClass('customer_last_name')" @click="toggleSort('customer_last_name')">Kunde</th>
          <th :class="sortClass('service_names')" @click="toggleSort('service_names')">Dienstleistungen</th>
          <th :class="sortClass('notes')" @click="toggleSort('notes')">Anmerkungen</th>
          <th style="text-align:right" :class="sortClass('amount')" @click="toggleSort('amount')">Betrag CHF</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="o in sorted" :key="o.id" class="clickable-row" @click="edit(o)">
          <td>{{ formatDate(o.order_date) }}</td>
          <td>{{ o.order_number || '–' }}</td>
          <td>{{ o.customer_first_name }} {{ o.customer_last_name }}</td>
          <td>{{ o.service_names || '–' }}</td>
          <td>{{ o.notes && o.notes.length > 50 ? o.notes.slice(0, 50) + '...' : (o.notes || '–') }}</td>
          <td style="text-align:right">{{ Number(o.amount).toFixed(2) }}</td>
          <td>
            <button class="btn btn-sm btn-danger" @click.stop="confirmDelete(o)">✕</button>
          </td>
        </tr>
      </tbody>
    </table>
    </div>

    <OrderModal
      v-if="showModal"
      :order="editOrder"
      @close="showModal = false"
      @saved="showModal = false; load()"
    />

    <ConfirmDialog
      :visible="!!deleteTarget"
      message="Auftrag wirklich löschen?"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import OrderModal from '../components/OrderModal.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { useSort } from '../composables/useSort.js'
import { formatDate } from '../utils/formatDate.js'

const orders = ref([])
const showModal = ref(false)
const editOrder = ref({})
const deleteTarget = ref(null)

const { sorted, toggleSort, sortClass } = useSort(orders, 'order_date', 'desc')

onMounted(load)

async function load() {
  orders.value = await api.get('orders.php')
}

function edit(order) {
  editOrder.value = { ...order }
  showModal.value = true
}

function confirmDelete(order) { deleteTarget.value = order }

async function doDelete() {
  await api.del(`orders.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>

<style scoped>
.clickable-row { cursor: pointer; }
</style>
