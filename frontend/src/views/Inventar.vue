<template>
  <div>
    <div class="page-header">
      <h1>Inventar</h1>
      <button class="btn btn-primary" @click="addItem">+ Neues Inventar</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('name')" @click="toggleSort('name')">Bezeichnung</th>
          <th style="text-align:right" :class="sortClass('value')" @click="toggleSort('value')">Wert CHF</th>
          <th :class="sortClass('purchase_date')" @click="toggleSort('purchase_date')">Kaufdatum</th>
          <th :class="sortClass('owner')" @click="toggleSort('owner')">Zuordnung</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in sorted" :key="item.id">
          <td><InlineEdit v-model="item.name" @update:model-value="v => update(item, 'name', v)" /></td>
          <td style="text-align:right"><InlineEdit v-model="item.value" type="number" @update:model-value="v => update(item, 'value', v)" /></td>
          <td><InlineEdit v-model="item.purchase_date" @update:model-value="v => update(item, 'purchase_date', v)" /></td>
          <td>
            <select :value="item.owner" @change="update(item, 'owner', $event.target.value)" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:14px">
              <option value="felix">Felix</option>
              <option value="araceli">Araceli</option>
            </select>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(item)">✕</button></td>
        </tr>
        <tr class="totals-row">
          <td>Total</td>
          <td style="text-align:right">{{ totalAll.toFixed(2) }}</td>
          <td colspan="3"></td>
        </tr>
        <tr>
          <td style="color:#6b7280">Felix</td>
          <td style="text-align:right;color:#6b7280">{{ totalFelix.toFixed(2) }}</td>
          <td colspan="3"></td>
        </tr>
        <tr>
          <td style="color:#6b7280">Araceli</td>
          <td style="text-align:right;color:#6b7280">{{ totalAraceli.toFixed(2) }}</td>
          <td colspan="3"></td>
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
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { useSort } from '../composables/useSort.js'

const items = ref([])

const { sorted, toggleSort, sortClass } = useSort(items, 'name', 'asc')
const deleteTarget = ref(null)

const totalAll = computed(() => items.value.reduce((sum, i) => sum + Number(i.value || 0), 0))
const totalFelix = computed(() => items.value.filter(i => i.owner === 'felix').reduce((sum, i) => sum + Number(i.value || 0), 0))
const totalAraceli = computed(() => items.value.filter(i => i.owner === 'araceli').reduce((sum, i) => sum + Number(i.value || 0), 0))

onMounted(load)

async function load() { items.value = await api.get('inventory.php') }

async function addItem() {
  await api.post('inventory.php', { name: 'Neuer Eintrag', value: 0, owner: 'felix' })
  await load()
}

async function update(item, field, value) {
  item[field] = value
  await api.put(`inventory.php?id=${item.id}`, { [field]: value })
}

function confirmDelete(item) { deleteTarget.value = item }

async function doDelete() {
  await api.del(`inventory.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
