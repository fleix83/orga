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
import { formatDate } from '../utils/formatDate.js'

const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  type: { type: String, default: 'text' },
})

const emit = defineEmits(['update:modelValue'])

const editing = ref(false)
const localValue = ref('')
const inputRef = ref(null)

const inputType = computed(() => {
  if (props.type === 'number' || props.type === 'int') return 'number'
  if (props.type === 'date') return 'date'
  return 'text'
})

const displayValue = computed(() => {
  if (props.modelValue === null || props.modelValue === '') return ''
  if (props.type === 'number') {
    return Number(props.modelValue).toFixed(2)
  }
  if (props.type === 'int') {
    return String(parseInt(props.modelValue, 10))
  }
  if (props.type === 'date') {
    return formatDate(props.modelValue)
  }
  return props.modelValue
})

function startEdit() {
  let initial = props.modelValue ?? ''
  // For date input, ensure YYYY-MM-DD format
  if (props.type === 'date' && typeof initial === 'string') {
    initial = initial.slice(0, 10)
  }
  localValue.value = initial
  editing.value = true
  nextTick(() => {
    if (props.type === 'date') {
      inputRef.value?.focus()
    } else {
      inputRef.value?.select()
    }
  })
}

function save() {
  editing.value = false
  let val
  if (props.type === 'number') {
    val = parseFloat(localValue.value) || 0
  } else if (props.type === 'int') {
    val = localValue.value === '' ? null : parseInt(localValue.value, 10)
  } else if (props.type === 'date') {
    val = localValue.value || null
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
