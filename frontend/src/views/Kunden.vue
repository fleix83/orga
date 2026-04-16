<template>
  <div>
    <div class="page-header">
      <h1>Kunden</h1>
      <div style="display:flex;gap:8px">
        <input v-model="search" class="search-input" placeholder="Suchen..." @input="loadCustomers">
        <button class="btn btn-primary" @click="addCustomer">+ Neuer Kunde</button>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Nr.</th>
          <th>Anrede</th>
          <th>Name</th>
          <th>Vorname</th>
          <th>Ort</th>
          <th>Telefon</th>
          <th>Email</th>
          <th style="text-align:right">Total CHF</th>
          <th style="text-align:right">Termine</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <template v-for="c in customers" :key="c.id">
          <tr>
            <td>{{ c.customer_number }}</td>
            <td><InlineEdit v-model="c.salutation" @update:model-value="v => updateField(c, 'salutation', v)" /></td>
            <td><InlineEdit v-model="c.last_name" @update:model-value="v => updateField(c, 'last_name', v)" /></td>
            <td><InlineEdit v-model="c.first_name" @update:model-value="v => updateField(c, 'first_name', v)" /></td>
            <td><InlineEdit v-model="c.city" @update:model-value="v => updateField(c, 'city', v)" /></td>
            <td><InlineEdit v-model="c.phone" @update:model-value="v => updateField(c, 'phone', v)" /></td>
            <td><InlineEdit v-model="c.email" @update:model-value="v => updateField(c, 'email', v)" /></td>
            <td style="text-align:right">{{ Number(c.total || 0).toFixed(2) }}</td>
            <td style="text-align:right">{{ c.order_count || 0 }}</td>
            <td>
              <button class="btn btn-sm" @click="toggleExpand(c.id)">{{ expanded === c.id ? '▲' : '▼' }}</button>
              <button class="btn btn-sm btn-danger" @click="confirmDelete(c)">✕</button>
            </td>
          </tr>
          <tr v-if="expanded === c.id" class="expand-row">
            <td colspan="10">
              <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px;max-width:600px">
                <div><label style="font-size:12px;color:#6b7280">Strasse</label><InlineEdit v-model="c.street" @update:model-value="v => updateField(c, 'street', v)" /></div>
                <div><label style="font-size:12px;color:#6b7280">PLZ</label><InlineEdit v-model="c.zip" @update:model-value="v => updateField(c, 'zip', v)" /></div>
                <div><label style="font-size:12px;color:#6b7280">Nationalität</label><InlineEdit v-model="c.nationality" @update:model-value="v => updateField(c, 'nationality', v)" /></div>
              </div>
              <div style="margin-top:8px"><label style="font-size:12px;color:#6b7280">Anmerkung</label><InlineEdit v-model="c.notes" @update:model-value="v => updateField(c, 'notes', v)" /></div>
            </td>
          </tr>
        </template>
      </tbody>
    </table>

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`${deleteTarget?.first_name} ${deleteTarget?.last_name} wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'

const customers = ref([])
const search = ref('')
const expanded = ref(null)
const deleteTarget = ref(null)

onMounted(loadCustomers)

async function loadCustomers() {
  const query = search.value ? `?search=${encodeURIComponent(search.value)}` : ''
  customers.value = await api.get(`customers.php${query}`)
}

async function addCustomer() {
  const result = await api.post('customers.php', { first_name: '', last_name: 'Neuer Kunde' })
  await loadCustomers()
  expanded.value = result.id
}

async function updateField(customer, field, value) {
  await api.put(`customers.php?id=${customer.id}`, { [field]: value })
}

function toggleExpand(id) {
  expanded.value = expanded.value === id ? null : id
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
