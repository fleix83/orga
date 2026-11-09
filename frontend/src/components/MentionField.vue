<template>
  <div class="mention-field">
    <textarea
      v-if="multiline"
      ref="el"
      :value="modelValue"
      :rows="rows"
      :placeholder="placeholder"
      @input="onInput"
      @keydown="onKeydown"
      @click="detect"
      @blur="open = false"
    ></textarea>
    <input
      v-else
      ref="el"
      type="text"
      :value="modelValue"
      :placeholder="placeholder"
      @input="onInput"
      @keydown="onKeydown"
      @click="detect"
      @blur="open = false"
    >
    <div v-if="open && matches.length" class="mention-panel">
      <button
        v-for="(m, i) in matches"
        :key="m.key"
        type="button"
        :class="['mention-option', { active: i === activeIndex }]"
        @mousedown.prevent="pick(m)"
        @mouseenter="activeIndex = i"
      >
        <span :class="['mention-type', m.type]">{{ m.type === 'customer' ? 'Kunde' : 'Buchung' }}</span>
        <span class="mention-label">{{ m.label }}</span>
        <span class="mention-sub">{{ m.sub }}</span>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, nextTick } from 'vue'

// Text field with @-autocomplete for customers and bookings. Picking a
// suggestion inserts "@Name" into the text and emits `mention` with the
// candidate, so the parent can link it to the task.
const props = defineProps({
  modelValue: { type: String, default: '' },
  candidates: { type: Array, default: () => [] },
  multiline: { type: Boolean, default: false },
  rows: { type: Number, default: 4 },
  placeholder: { type: String, default: '' },
})

const emit = defineEmits(['update:modelValue', 'mention', 'enter', 'escape'])

const el = ref(null)
const open = ref(false)
const query = ref('')
const activeIndex = ref(0)
let atStart = -1

const MAX_MATCHES = 8

const matches = computed(() => {
  const tokens = query.value.toLowerCase().split(/\s+/).filter(Boolean)
  const result = []
  for (const c of props.candidates) {
    const haystack = `${c.label} ${c.sub}`.toLowerCase()
    if (tokens.every(t => haystack.includes(t))) result.push(c)
    if (result.length >= MAX_MATCHES) break
  }
  return result
})

// Looks for an "@query" directly before the caret ("@" at line start or after a space).
function detect() {
  const node = el.value
  const before = node.value.slice(0, node.selectionStart)
  const m = before.match(/(^|\s)@([^@\n]{0,40})$/)
  if (!m) {
    open.value = false
    return
  }
  atStart = before.length - m[2].length - 1
  query.value = m[2]
  activeIndex.value = 0
  open.value = true
}

function onInput(e) {
  emit('update:modelValue', e.target.value)
  detect()
}

function onKeydown(e) {
  if (open.value && matches.value.length) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      activeIndex.value = (activeIndex.value + 1) % matches.value.length
      return
    }
    if (e.key === 'ArrowUp') {
      e.preventDefault()
      activeIndex.value = (activeIndex.value - 1 + matches.value.length) % matches.value.length
      return
    }
    if (e.key === 'Enter' || e.key === 'Tab') {
      e.preventDefault()
      pick(matches.value[activeIndex.value])
      return
    }
    if (e.key === 'Escape') {
      e.preventDefault()
      e.stopPropagation()
      open.value = false
      return
    }
  }
  if (e.key === 'Enter' && !props.multiline) {
    e.preventDefault()
    emit('enter')
  } else if (e.key === 'Escape') {
    emit('escape')
  }
}

function pick(candidate) {
  const node = el.value
  const caret = node.selectionStart
  const insert = `@${candidate.label} `
  const text = node.value.slice(0, atStart) + insert + node.value.slice(caret)
  emit('update:modelValue', text)
  emit('mention', candidate)
  open.value = false
  const pos = atStart + insert.length
  nextTick(() => {
    node.focus()
    node.setSelectionRange(pos, pos)
  })
}

defineExpose({ focus: () => el.value?.focus() })
</script>

<style scoped>
.mention-field { position: relative; }

textarea { resize: vertical; }

.mention-panel {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08);
  z-index: 20;
  max-height: 280px;
  overflow-y: auto;
  padding: 6px;
}

.mention-option {
  display: flex;
  align-items: baseline;
  gap: 8px;
  width: 100%;
  appearance: none;
  border: none;
  background: transparent;
  text-align: left;
  padding: 7px 10px;
  border-radius: 6px;
  font: inherit;
  font-size: 14px;
  color: #111827;
  cursor: pointer;
}

.mention-option.active { background: #f3f4f6; }

.mention-type {
  flex-shrink: 0;
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  padding: 1px 6px;
  border-radius: 4px;
}

.mention-type.customer { background: #e0e7ff; color: #3730a3; }
.mention-type.order { background: #fff3bf; color: #7c5e00; }

.mention-label {
  flex-shrink: 0;
  font-weight: 600;
}

.mention-sub {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 13px;
  color: #6b7280;
}
</style>
