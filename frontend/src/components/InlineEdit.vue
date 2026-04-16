<template>
  <span v-if="!editing" class="inline-edit" @click="startEdit">
    {{ displayValue || '–' }}
  </span>
  <input
    v-else
    ref="inputRef"
    v-model="localValue"
    :type="inputType"
    class="inline-edit"
    @keydown.enter="save"
    @keydown.tab="save"
    @keydown.escape="cancel"
    @blur="save"
  >
</template>

<script setup>
import { ref, nextTick, computed } from 'vue'

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  type: { type: String, default: 'text' },
})

const emit = defineEmits(['update:modelValue'])

const editing = ref(false)
const localValue = ref('')
const inputRef = ref(null)

const inputType = computed(() => (props.type === 'number' || props.type === 'int') ? 'number' : 'text')
const displayValue = computed(() => {
  if (props.type === 'number' && props.modelValue !== null && props.modelValue !== '') {
    return Number(props.modelValue).toFixed(2)
  }
  if (props.type === 'int' && props.modelValue !== null && props.modelValue !== '') {
    return String(parseInt(props.modelValue, 10))
  }
  return props.modelValue
})

function startEdit() {
  localValue.value = props.modelValue ?? ''
  editing.value = true
  nextTick(() => inputRef.value?.select())
}

function save() {
  editing.value = false
  let val
  if (props.type === 'number') {
    val = parseFloat(localValue.value) || 0
  } else if (props.type === 'int') {
    val = localValue.value === '' ? null : parseInt(localValue.value, 10)
  } else {
    val = localValue.value
  }
  if (val !== props.modelValue) {
    emit('update:modelValue', val)
  }
}

function cancel() {
  editing.value = false
}
</script>
