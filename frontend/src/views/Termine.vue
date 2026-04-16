<template>
  <div>
    <div class="page-header">
      <h1>Termine</h1>
    </div>

    <table>
      <thead>
        <tr>
          <th>Datum</th>
          <th>Uhrzeit</th>
          <th>Typ</th>
          <th>Kunde</th>
          <th>Dienstleistungen</th>
          <th style="text-align:right">CHF</th>
          <th>Status</th>
          <th>Notizen</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="t in appointments" :key="t.id">
          <td>{{ t.event_date }}</td>
          <td>{{ t.time_display }}</td>
          <td><span class="badge" :style="{ background: t.color + '33', color: t.color }">{{ t.event_type }}</span></td>
          <td>{{ t.customer_first_name ? `${t.customer_first_name} ${t.customer_last_name}` : '–' }}</td>
          <td>{{ t.service_names || '–' }}</td>
          <td style="text-align:right">{{ t.total_price ? Number(t.total_price).toFixed(2) : '–' }}</td>
          <td>
            <select :value="t.status" @change="updateStatus(t, $event.target.value)" style="padding:2px 6px;border:1px solid #e5e7eb;border-radius:4px;font-size:13px">
              <option value="pending">Ausstehend</option>
              <option value="confirmed">Bestätigt</option>
              <option value="completed">Abgeschlossen</option>
              <option value="cancelled">Abgesagt</option>
            </select>
          </td>
          <td><InlineEdit v-model="t.notes" @update:model-value="v => updateNotes(t, v)" /></td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../api.js'
import InlineEdit from '../components/InlineEdit.vue'

const appointments = ref([])

onMounted(async () => {
  appointments.value = await api.get('appointments.php')
})

async function updateStatus(appointment, status) {
  appointment.status = status
  await api.put(`appointments.php?id=${appointment.id}`, { status })
}

async function updateNotes(appointment, notes) {
  await api.put(`appointments.php?id=${appointment.id}`, { notes })
}
</script>
