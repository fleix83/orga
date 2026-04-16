<template>
  <div v-if="visible" class="modal-overlay" @click.self="cancel">
    <div class="modal" style="max-width:400px">
      <p>{{ message }}</p>
      <div class="form-actions">
        <button class="btn" @click="cancel">Abbrechen</button>
        <button class="btn btn-danger" @click="confirm">Löschen</button>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  visible: { type: Boolean, default: false },
  message: { type: String, default: 'Wirklich löschen?' },
})

const emit = defineEmits(['confirm', 'cancel'])

function confirm() { emit('confirm') }
function cancel() { emit('cancel') }
</script>
