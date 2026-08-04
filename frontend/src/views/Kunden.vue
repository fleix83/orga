<template>
  <div>
    <div class="page-header">
      <h1>Kunden</h1>
      <div style="display:flex;gap:8px">
        <input v-model="search" class="search-input" placeholder="Suchen..." @input="loadCustomers">
        <button class="btn btn-primary" @click="openNew">+ Neuer Kunde</button>
      </div>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('customer_number')" @click="toggleSort('customer_number')">Nr.</th>
          <th :class="sortClass('salutation')" @click="toggleSort('salutation')">Anrede</th>
          <th :class="sortClass('last_name')" @click="toggleSort('last_name')">Name</th>
          <th :class="sortClass('first_name')" @click="toggleSort('first_name')">Vorname</th>
          <th :class="sortClass('city')" @click="toggleSort('city')">Ort</th>
          <th :class="sortClass('phone')" @click="toggleSort('phone')">Telefon</th>
          <th :class="sortClass('email')" @click="toggleSort('email')">Email</th>
          <th style="text-align:right" :class="sortClass('total')" @click="toggleSort('total')">Total CHF</th>
          <th style="text-align:right" :class="sortClass('order_count')" @click="toggleSort('order_count')">Termine</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="c in sorted" :key="c.id" class="clickable-row" @click="openEdit(c)">
          <td>{{ c.customer_number || '–' }}</td>
          <td>{{ c.salutation || '–' }}</td>
          <td>{{ c.last_name || '–' }}</td>
          <td>{{ c.first_name || '–' }}</td>
          <td>{{ c.city || '–' }}</td>
          <td>{{ c.phone || '–' }}</td>
          <td>{{ c.email || '–' }}</td>
          <td style="text-align:right">{{ Number(c.total || 0).toFixed(2) }}</td>
          <td style="text-align:right">{{ c.order_count || 0 }}</td>
          <td @click.stop>
            <button class="btn btn-sm btn-danger" @click="confirmDelete(c)">✕</button>
          </td>
        </tr>
      </tbody>
    </table>
    </div>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`${deleteTarget?.first_name} ${deleteTarget?.last_name} wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />

    <CustomerModal
      v-if="showModal"
      :customer-id="modalCustomerId"
      @close="closeModal"
      @saved="closeModal(); loadCustomers()"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import CustomerModal from '../components/CustomerModal.vue'
import { useSort } from '../composables/useSort.js'

const customers = ref([])

const { sorted, toggleSort, sortClass } = useSort(customers, 'last_name', 'asc')
const search = ref('')
const deleteTarget = ref(null)

// Modal state
const showModal = ref(false)
const modalCustomerId = ref(null)

onMounted(loadCustomers)

async function loadCustomers() {
  const query = search.value ? `?search=${encodeURIComponent(search.value)}` : ''
  customers.value = await api.get(`customers.php${query}`)
}

function openNew() {
  modalCustomerId.value = null
  showModal.value = true
}

function openEdit(customer) {
  modalCustomerId.value = customer.id
  showModal.value = true
}

function closeModal() {
  showModal.value = false
  modalCustomerId.value = null
}

function confirmDelete(customer) {
  deleteTarget.value = customer
}

async function doDelete() {
  await api.del(`customers.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await loadCustomers()
}
</script>
