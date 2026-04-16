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
          <th>Datum</th>
          <th>Kunde</th>
          <th>Dienstleistungen</th>
          <th>Anmerkungen</th>
          <th style="text-align:right">Betrag CHF</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="o in orders" :key="o.id">
          <td>{{ o.order_date }}</td>
          <td>{{ o.customer_first_name }} {{ o.customer_last_name }}</td>
          <td>{{ o.service_names || '–' }}</td>
          <td>{{ o.notes && o.notes.length > 50 ? o.notes.slice(0, 50) + '...' : (o.notes || '–') }}</td>
          <td style="text-align:right">{{ Number(o.amount).toFixed(2) }}</td>
          <td>
            <button class="btn btn-sm" @click="edit(o)">✎</button>
            <button class="btn btn-sm btn-danger" @click="confirmDelete(o)">✕</button>
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

const orders = ref([])
const showModal = ref(false)
const editOrder = ref({})
const deleteTarget = ref(null)

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
