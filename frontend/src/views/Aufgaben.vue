<template>
  <div>
    <div class="page-header">
      <h1>Aufgaben</h1>
      <div class="header-actions">
        <input v-model="search" type="search" class="search-input" placeholder="Suchen …">
        <button class="btn btn-primary" @click="openTask({})">+ Neue Aufgabe</button>
      </div>
    </div>

    <div class="board">
      <section
        v-for="col in TASK_COLUMNS"
        :key="col.key"
        :class="['board-column', { 'drop-active': dropColumn === col.key }]"
        @dragover.prevent="onDragOver($event, col.key)"
        @dragleave="onDragLeave($event)"
        @drop.prevent="onDrop(col.key)"
      >
        <header class="column-header">
          <span :class="['column-dot', col.key]"></span>
          <h2>{{ col.label }}</h2>
          <span class="column-count">{{ columnTasks(col.key).length }}</span>
        </header>

        <div class="column-cards" :ref="el => (listRefs[col.key] = el)">
          <template v-for="entry in renderEntries(col.key)" :key="entry.key">
            <div v-if="entry.placeholder" class="drop-placeholder"></div>
            <article
              v-else
              :class="['task-card', { dragging: dragId === entry.task.id, done: entry.task.status === 'done' }]"
              :data-id="entry.task.id"
              draggable="true"
              @dragstart="onDragStart($event, entry.task)"
              @dragend="resetDrag"
              @click="openTask(entry.task)"
            >
              <div class="card-top">
                <button
                  type="button"
                  :class="['card-check', { on: entry.task.status === 'done' }]"
                  :title="entry.task.status === 'done' ? 'Wieder öffnen' : 'Als erledigt markieren'"
                  @click.stop="toggleDone(entry.task)"
                >✓</button>
                <span class="card-title">{{ entry.task.title }}</span>
              </div>
              <p v-if="entry.task.notes" class="card-notes">{{ entry.task.notes }}</p>
              <div v-if="entry.task.due_date || entry.task.links.length" class="card-meta">
                <span v-if="entry.task.due_date" :class="['due', dueClass(entry.task)]">
                  {{ dueLabel(entry.task.due_date) }}
                </span>
                <TaskLinkChip
                  v-for="link in entry.task.links"
                  :key="linkKey(link)"
                  :link="link"
                  @open="openLink"
                />
              </div>
            </article>
          </template>

          <div v-if="!columnTasks(col.key).length && dropColumn !== col.key" class="column-empty">
            {{ search ? 'Keine Treffer' : 'Keine Aufgaben' }}
          </div>
        </div>

        <div v-if="quickAddColumn === col.key" class="quick-add">
          <MentionField
            ref="quickAddRef"
            v-model="quickAddTitle"
            :candidates="candidates"
            placeholder="Titel, Enter zum Speichern"
            @mention="quickAddLinks.push($event.link)"
            @enter="submitQuickAdd(col.key)"
            @escape="closeQuickAdd"
          />
        </div>
        <button v-else type="button" class="quick-add-btn" @click="startQuickAdd(col.key)">+ Aufgabe</button>
      </section>
    </div>

    <TaskModal
      v-if="editTask"
      :task="editTask"
      :candidates="candidates"
      @close="editTask = null"
      @saved="editTask = null; load()"
      @delete="deleteTarget = $event"
      @open-link="openLink"
    />

    <CustomerModal
      v-if="customerModalId"
      :customer-id="customerModalId"
      @close="customerModalId = null"
      @saved="customerModalId = null; reloadAll()"
    />

    <OrderModal
      v-if="orderModal"
      :order="orderModal"
      @close="orderModal = null; load()"
      @saved="orderModal = null; reloadAll()"
      @created="reloadAll()"
    />

    <ConfirmDialog
      :visible="!!deleteTarget"
      :message="`Aufgabe '${deleteTarget?.title}' wirklich löschen?`"
      @confirm="doDelete"
      @cancel="deleteTarget = null"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { api } from '../api.js'
import TaskModal from '../components/TaskModal.vue'
import TaskLinkChip from '../components/TaskLinkChip.vue'
import MentionField from '../components/MentionField.vue'
import CustomerModal from '../components/CustomerModal.vue'
import OrderModal from '../components/OrderModal.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { TASK_COLUMNS } from '../utils/taskColumns.js'
import { buildCandidates, linkKey, linkLabel, shortDate } from '../utils/taskLinks.js'

const tasks = ref([])
const candidates = ref([])
const search = ref('')

const editTask = ref(null)
const deleteTarget = ref(null)
const customerModalId = ref(null)
const orderModal = ref(null)

onMounted(reloadAll)

async function load() {
  tasks.value = await api.get('tasks.php')
}

async function loadCandidates() {
  const [customers, orders] = await Promise.all([api.get('customers.php'), api.get('orders.php')])
  candidates.value = buildCandidates(customers, orders)
}

function reloadAll() {
  return Promise.all([load(), loadCandidates()])
}

const filteredTasks = computed(() => {
  const tokens = search.value.toLowerCase().split(/\s+/).filter(Boolean)
  if (!tokens.length) return tasks.value
  return tasks.value.filter(t => {
    const haystack = [t.title, t.notes, ...t.links.map(linkLabel)].join(' ').toLowerCase()
    return tokens.every(tok => haystack.includes(tok))
  })
})

function columnTasks(status) {
  return filteredTasks.value
    .filter(t => t.status === status)
    .sort((a, b) => a.position - b.position || a.id - b.id)
}

// ── Due dates ──────────────────────────────────────────────
function todayIso() {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

function dueClass(task) {
  if (task.status === 'done') return ''
  const due = String(task.due_date).slice(0, 10)
  const today = todayIso()
  if (due < today) return 'overdue'
  if (due === today) return 'today'
  return ''
}

function dueLabel(date) {
  return String(date).slice(0, 10) === todayIso() ? 'Heute' : shortDate(date)
}

// ── Modals ─────────────────────────────────────────────────
function openTask(task) {
  editTask.value = { ...task, links: [...(task.links || [])] }
}

async function openLink(link) {
  if (link.customer_id) {
    customerModalId.value = link.customer_id
  } else {
    // OrderModal initialises its form from the passed object, so it needs the full record.
    orderModal.value = await api.get(`orders.php?id=${link.order_id}`)
  }
}

async function doDelete() {
  await api.del(`tasks.php?id=${deleteTarget.value.id}`)
  deleteTarget.value = null
  editTask.value = null
  await load()
}

async function toggleDone(task) {
  const status = task.status === 'done' ? 'todo' : 'done'
  await api.put(`tasks.php?id=${task.id}`, { status })
  await load()
}

// ── Quick add ──────────────────────────────────────────────
const quickAddColumn = ref(null)
const quickAddTitle = ref('')
const quickAddLinks = ref([])
const quickAddRef = ref(null)

function startQuickAdd(status) {
  quickAddColumn.value = status
  quickAddTitle.value = ''
  quickAddLinks.value = []
  nextTick(() => quickAddRef.value?.[0]?.focus())
}

function closeQuickAdd() {
  quickAddColumn.value = null
}

// Stays open after saving so several tasks can be typed in a row.
async function submitQuickAdd(status) {
  const title = quickAddTitle.value.trim()
  if (!title) return closeQuickAdd()
  const links = quickAddLinks.value.map(l => (l.customer_id ? { customer_id: l.customer_id } : { order_id: l.order_id }))
  quickAddTitle.value = ''
  quickAddLinks.value = []
  await api.post('tasks.php', { title, status, links })
  await load()
}

// ── Drag & drop ────────────────────────────────────────────
const dragId = ref(null)
const dropColumn = ref(null)
const dropIndex = ref(0)
const listRefs = {}

function onDragStart(e, task) {
  dragId.value = task.id
  e.dataTransfer.effectAllowed = 'move'
  e.dataTransfer.setData('text/plain', String(task.id)) // Firefox needs data to start a drag
}

// Drop index = number of (non-dragged) cards whose vertical middle lies above the pointer.
function onDragOver(e, status) {
  if (dragId.value === null) return
  e.dataTransfer.dropEffect = 'move'
  dropColumn.value = status
  const cards = [...(listRefs[status]?.querySelectorAll('.task-card') || [])]
    .filter(el => Number(el.dataset.id) !== dragId.value)
  let index = cards.length
  for (let i = 0; i < cards.length; i++) {
    const rect = cards[i].getBoundingClientRect()
    if (e.clientY < rect.top + rect.height / 2) {
      index = i
      break
    }
  }
  dropIndex.value = index
}

function onDragLeave(e) {
  if (!e.currentTarget.contains(e.relatedTarget)) dropColumn.value = null
}

// Cards of a column plus the drop placeholder; the dragged card stays in
// place (faded) so the browser does not cancel the drag.
function renderEntries(status) {
  const entries = []
  let index = 0
  const showPlaceholder = dropColumn.value === status
  for (const task of columnTasks(status)) {
    const isDragged = task.id === dragId.value
    if (!isDragged && showPlaceholder && index === dropIndex.value) {
      entries.push({ key: 'placeholder', placeholder: true })
    }
    entries.push({ key: task.id, task })
    if (!isDragged) index++
  }
  if (showPlaceholder && index <= dropIndex.value) entries.push({ key: 'placeholder', placeholder: true })
  return entries
}

async function onDrop(status) {
  const id = dragId.value
  if (id === null) return
  const task = tasks.value.find(t => t.id === id)
  // Reorder against the full column (not only search hits) so hidden cards keep their place.
  const ordered = tasks.value
    .filter(t => t.status === status && t.id !== id)
    .sort((a, b) => a.position - b.position || a.id - b.id)
  const visible = columnTasks(status).filter(t => t.id !== id)
  const anchor = visible[dropIndex.value]
  const insertAt = anchor ? ordered.indexOf(anchor) : ordered.length
  ordered.splice(insertAt, 0, task)

  resetDrag()
  task.status = status
  ordered.forEach((t, i) => { t.position = i })

  try {
    await api.put('tasks.php?action=reorder', { status, ids: ordered.map(t => t.id) })
  } finally {
    await load()
  }
}

function resetDrag() {
  dragId.value = null
  dropColumn.value = null
}
</script>

<style scoped>
.header-actions {
  display: flex;
  gap: 10px;
  align-items: center;
}

.header-actions .search-input { width: 220px; }

.board {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 18px;
  align-items: start;
}

.board-column {
  background: rgba(255, 255, 255, 0.5);
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  padding: 14px 12px 10px;
  transition: border-color 0.12s ease, background 0.12s ease;
}

.board-column.drop-active {
  border-color: #728fef;
  background: rgba(255, 255, 255, 0.75);
}

.column-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 4px 12px;
}

.column-header h2 {
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: #374151;
}

.column-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.column-dot.todo { background: #9ca3af; }
.column-dot.doing { background: #728fef; }
.column-dot.done { background: #10b981; }

.column-count {
  margin-left: auto;
  font-size: 12px;
  font-weight: 600;
  color: #9ca3af;
}

.column-cards {
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 48px;
}

.column-empty {
  padding: 14px 0;
  text-align: center;
  font-size: 13px;
  color: #9ca3af;
}

.task-card {
  background: #fff;
  border: 1px solid #eceef2;
  border-radius: 10px;
  padding: 10px 12px;
  box-shadow: 0 1px 2px rgba(17, 24, 39, 0.04);
  cursor: pointer;
  transition: box-shadow 0.12s ease, border-color 0.12s ease, opacity 0.12s ease;
}

.task-card:hover {
  border-color: #d1d5db;
  box-shadow: 0 3px 10px rgba(17, 24, 39, 0.07);
}

.task-card.dragging { opacity: 0.35; }

.task-card.done .card-title {
  color: #6b7280;
  text-decoration: line-through;
  text-decoration-color: #d1d5db;
}

.drop-placeholder {
  height: 4px;
  border-radius: 2px;
  background: #728fef;
  margin: -2px 0;
}

.card-top {
  display: flex;
  align-items: flex-start;
  gap: 9px;
}

.card-check {
  appearance: none;
  flex-shrink: 0;
  width: 18px;
  height: 18px;
  margin-top: 1px;
  border: 1.5px solid #d1d5db;
  border-radius: 50%;
  background: #fff;
  color: transparent;
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: border-color 0.12s ease, background 0.12s ease, color 0.12s ease;
}

.card-check:hover { border-color: #10b981; color: #10b981; }

.card-check.on {
  background: #10b981;
  border-color: #10b981;
  color: #fff;
}

.card-title {
  font-size: 14px;
  font-weight: 600;
  line-height: 1.4;
  overflow-wrap: anywhere;
}

.card-notes {
  margin: 6px 0 0 27px;
  font-size: 13px;
  color: #6b7280;
  white-space: pre-line;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  overflow-wrap: anywhere;
}

.card-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  margin: 8px 0 0 27px;
}

.due {
  font-size: 12px;
  font-weight: 600;
  padding: 2px 7px;
  border-radius: 6px;
  background: #f3f4f6;
  color: #4b5563;
  line-height: 1.4;
}

.due.today { background: #fef3c7; color: #92400e; }
.due.overdue { background: #fee2e2; color: #991b1b; }

.quick-add { margin-top: 8px; }

.quick-add-btn {
  appearance: none;
  display: block;
  width: 100%;
  margin-top: 8px;
  padding: 8px 6px;
  border: none;
  border-radius: 8px;
  background: transparent;
  font: inherit;
  font-size: 13px;
  font-weight: 500;
  color: #6b7280;
  text-align: left;
  cursor: pointer;
}

.quick-add-btn:hover { background: rgba(17, 24, 39, 0.04); color: #111827; }

/* Mobile: columns scroll sideways, one column per screen */
@media (max-width: 900px) {
  .header-actions { width: 100%; }
  .header-actions .search-input { flex: 1; width: auto; }

  .board {
    grid-template-columns: repeat(3, 85%);
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    -webkit-overflow-scrolling: touch;
    padding-bottom: 8px;
  }

  .board-column { scroll-snap-align: start; }
}
</style>
