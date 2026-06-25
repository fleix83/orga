<template>
  <div>
    <div class="page-header">
      <h1>Dienstleistungen</h1>
      <button class="btn btn-primary" @click="addService">+ Neue Dienstleistung</button>
    </div>

    <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th :class="sortClass('name')" @click="toggleSort('name')">Name</th>
          <th style="text-align:right" :class="sortClass('price')" @click="toggleSort('price')">Preis CHF</th>
          <th :class="sortClass('description')" @click="toggleSort('description')">Beschreibung</th>
          <th :class="sortClass('active')" @click="toggleSort('active')">Aktiv</th>
          <th :class="sortClass('is_public')" @click="toggleSort('is_public')">Online buchbar</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="s in sorted" :key="s.id">
          <td>
            <InlineEdit v-model="s.name" @update:model-value="v => update(s, 'name', v)" />
            <span v-if="s.is_public == 0" class="badge badge-internal" title="Nur intern – nicht online buchbar">intern</span>
          </td>
          <td style="text-align:right"><InlineEdit v-model="s.price" type="number" @update:model-value="v => update(s, 'price', v)" /></td>
          <td><InlineEdit v-model="s.description" @update:model-value="v => update(s, 'description', v)" /></td>
          <td>
            <span class="toggle" :class="{ active: s.active == 1 }" @click="toggleActive(s)">
              {{ s.active == 1 ? '✓ Aktiv' : '✗ Inaktiv' }}
            </span>
          </td>
          <td>
            <span class="toggle" :class="{ active: s.is_public == 1 }" @click="togglePublic(s)">
              {{ s.is_public == 1 ? '✓ Online' : '✗ Nur intern' }}
            </span>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(s)">✕</button></td>
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
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { useSort } from '../composables/useSort.js'

const services = ref([])

const { sorted, toggleSort, sortClass } = useSort(services, 'sort_order', 'asc')
const deleteTarget = ref(null)

onMounted(load)

async function load() {
  services.value = await api.get('services.php')
}

async function addService() {
  await api.post('services.php', { name: 'Neue Dienstleistung', price: 0, active: 1, is_public: 1 })
  await load()
}

async function update(service, field, value) {
  await api.put(`services.php?id=${service.id}`, { [field]: value })
}

async function toggleActive(service) {
  service.active = service.active == 1 ? 0 : 1
  await api.put(`services.php?id=${service.id}`, { active: service.active })
}

async function togglePublic(service) {
  service.is_public = service.is_public == 1 ? 0 : 1
  await api.put(`services.php?id=${service.id}`, { is_public: service.is_public })
}

function confirmDelete(service) { deleteTarget.value = service }

async function doDelete() {
  await api.del(`services.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
