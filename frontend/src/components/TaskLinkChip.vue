<template>
  <span :class="['task-chip', link.customer_id ? 'customer' : 'order']" :title="linkTitle(link)">
    <button type="button" class="task-chip-label" @click.stop="$emit('open', link)">@{{ linkLabel(link) }}</button>
    <button
      v-if="removable"
      type="button"
      class="task-chip-remove"
      title="Verknüpfung entfernen"
      @click.stop="$emit('remove', link)"
    >×</button>
  </span>
</template>

<script setup>
import { linkLabel, linkTitle } from '../utils/taskLinks.js'

defineProps({
  link: { type: Object, required: true },
  removable: { type: Boolean, default: false },
})

defineEmits(['open', 'remove'])
</script>

<style scoped>
.task-chip {
  display: inline-flex;
  align-items: center;
  max-width: 100%;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  line-height: 1.4;
}

.task-chip.customer { background: #e0e7ff; color: #3730a3; }
.task-chip.order { background: #fff3bf; color: #7c5e00; }

.task-chip-label,
.task-chip-remove {
  appearance: none;
  border: none;
  background: transparent;
  font: inherit;
  color: inherit;
  cursor: pointer;
}

.task-chip-label {
  padding: 2px 7px;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.task-chip-label:hover { text-decoration: underline; }

.task-chip-remove {
  padding: 2px 6px 2px 0;
  opacity: 0.55;
}

.task-chip-remove:hover { opacity: 1; }
</style>
