<template>
  <div>
    <div class="page-header">
      <h1>Dienstleistungen</h1>
      <button class="btn btn-primary" @click="addService">+ Neue Dienstleistung</button>
    </div>

    <table>
      <thead>
        <tr>
          <th>Name</th>
          <th style="text-align:right">Preis CHF</th>
          <th>Beschreibung</th>
          <th>Aktiv</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="s in services" :key="s.id">
          <td><InlineEdit v-model="s.name" @update:model-value="v => update(s, 'name', v)" /></td>
          <td style="text-align:right"><InlineEdit v-model="s.price" type="number" @update:model-value="v => update(s, 'price', v)" /></td>
          <td><InlineEdit v-model="s.description" @update:model-value="v => update(s, 'description', v)" /></td>
          <td>
            <span class="toggle" :class="{ active: s.active == 1 }" @click="toggleActive(s)">
              {{ s.active == 1 ? '✓ Aktiv' : '✗ Inaktiv' }}
            </span>
          </td>
          <td><button class="btn btn-sm btn-danger" @click="confirmDelete(s)">✕</button></td>
        </tr>
      </tbody>
    </table>

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

const services = ref([])
const deleteTarget = ref(null)

onMounted(load)

async function load() {
  services.value = await api.get('services.php')
}

async function addService() {
  await api.post('services.php', { name: 'Neue Dienstleistung', price: 0, active: 1 })
  await load()
}

async function update(service, field, value) {
  await api.put(`services.php?id=${service.id}`, { [field]: value })
}

async function toggleActive(service) {
  service.active = service.active == 1 ? 0 : 1
  await api.put(`services.php?id=${service.id}`, { active: service.active })
}

function confirmDelete(service) { deleteTarget.value = service }

async function doDelete() {
  await api.del(`services.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  await load()
}
</script>
