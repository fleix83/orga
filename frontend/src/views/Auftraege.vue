<template>
  <div>
    <div class="page-header">
      <h1>Buchung</h1>
      <button class="btn btn-primary" @click="showModal = true; editOrder = {}">+ Neue Buchung</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('order_date')" @click="toggleSort('order_date')">Datum</th>
          <th :class="sortClass('order_number')" @click="toggleSort('order_number')">Nr.</th>
          <th :class="sortClass('customer_last_name')" @click="toggleSort('customer_last_name')">Kunde</th>
          <th class="col-services" :class="sortClass('service_names')" @click="toggleSort('service_names')">Dienstleistungen</th>
          <th class="col-amount" :class="sortClass('amount')" @click="toggleSort('amount')">Betrag</th>
          <th :class="sortClass('notes')" @click="toggleSort('notes')">Anmerkungen</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="o in sorted"
          :key="o.id"
          :class="['clickable-row', { 'row-done': effectiveStatus(o) === 'done' }]"
          @click="edit(o)"
        >
          <td>
            <span class="date-cell">
              <span :class="['status-indicator', effectiveStatus(o)]"></span>
              {{ formatDate(o.order_date) }}
            </span>
          </td>
          <td>{{ o.order_number || '–' }}</td>
          <td>
            <span class="customer-link" @click.stop="openCustomer(o.customer_id)">
              {{ o.customer_first_name }} {{ o.customer_last_name }}
            </span>
          </td>
          <td class="col-services" :title="o.service_names || ''">{{ o.service_names || '–' }}</td>
          <td class="col-amount">
            {{ Number(o.amount).toFixed(2) }}<span :class="['amount-check', { on: Number(o.amount_confirmed) }]">✓</span>
          </td>
          <td>{{ o.notes && o.notes.length > 50 ? o.notes.slice(0, 50) + '...' : (o.notes || '–') }}</td>
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
      @created="load()"
    />

    <CustomerModal
      v-if="customerModalId"
      :customer-id="customerModalId"
      @close="customerModalId = null"
      @saved="customerModalId = null; load()"
    />

    <ConfirmDialog
      :visible="!!deleteTarget"
      message="Buchung wirklich löschen?"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import OrderModal from '../components/OrderModal.vue'
import CustomerModal from '../components/CustomerModal.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { useSort } from '../composables/useSort.js'
import { formatDate } from '../utils/formatDate.js'

const orders = ref([])
const showModal = ref(false)
const editOrder = ref({})
const deleteTarget = ref(null)
const customerModalId = ref(null)

const { sorted, toggleSort, sortClass } = useSort(orders, 'order_date', 'desc')

onMounted(load)

async function load() {
  orders.value = await api.get('orders.php')
}

function edit(order) {
  editOrder.value = { ...order }
  showModal.value = true
}

// Manually set status wins; otherwise derived from the date (today counts as pending).
function effectiveStatus(order) {
  if (order.status) return order.status
  const now = new Date()
  const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
  return String(order.order_date).slice(0, 10) >= today ? 'pending' : 'done'
}

function openCustomer(customerId) {
  if (customerId) customerModalId.value = customerId
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

.date-cell {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
}

/* Blau = pendent (zukünftig oder manuell); erledigte Buchungen bleiben ohne Punkt,
   der Platzhalter hält die Daten aller Zeilen bündig. */
.status-indicator {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}

.status-indicator.pending { background: #728fef; }

/* Dienstleistungen tightly capped (full text via tooltip / modal) so the
   Betrag column stays prominent */
.col-services {
  max-width: 140px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Narrow Betrag column; hidden check placeholder keeps the numbers aligned */
.col-amount {
  text-align: right;
  white-space: nowrap;
  width: 90px;
}

.amount-check {
  display: inline-block;
  width: 14px;
  margin-left: 4px;
  color: #10b981;
  visibility: hidden;
}

.amount-check.on { visibility: visible; }

/* Erledigte Buchungen: Text leicht abgedunkelt, klar unterscheidbar von pendenten */
.row-done td,
.row-done .customer-link {
  color: #6b7280;
}

.customer-link {
  cursor: pointer;
  text-decoration-line: underline;
  text-decoration-style: dotted;
  text-decoration-color: #d1d5db;
  text-underline-offset: 3px;
}

.customer-link:hover {
  color: #111827;
  text-decoration-color: #9ca3af;
}
</style>
