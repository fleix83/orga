import { ref, computed } from 'vue'

/**
 * Provides sortable table state.
 *
 * Usage:
 *   const items = ref([])
 *   const { sorted, sortColumn, sortDir, toggleSort, sortClass } = useSort(items)
 *
 *   <th :class="sortClass('name')" @click="toggleSort('name')">Name</th>
 *   <tr v-for="x in sorted" ...>
 */
export function useSort(itemsRef, initialColumn = null, initialDir = 'asc') {
  const sortColumn = ref(initialColumn)
  const sortDir = ref(initialDir)

  const sorted = computed(() => {
    const items = itemsRef.value || []
    if (!sortColumn.value) return items
    const col = sortColumn.value
    const factor = sortDir.value === 'asc' ? 1 : -1

    return [...items].sort((a, b) => {
      let av = a[col]
      let bv = b[col]

      // Handle null/undefined — push to end regardless of dir
      if (av == null && bv == null) return 0
      if (av == null) return 1
      if (bv == null) return -1

      // Numeric compare when both are numbers
      const aNum = Number(av)
      const bNum = Number(bv)
      if (!isNaN(aNum) && !isNaN(bNum) && av !== '' && bv !== '') {
        return (aNum - bNum) * factor
      }

      // String compare with locale
      return String(av).localeCompare(String(bv), 'de', { numeric: true }) * factor
    })
  })

  function toggleSort(column) {
    if (sortColumn.value === column) {
      sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
    } else {
      sortColumn.value = column
      sortDir.value = 'asc'
    }
  }

  function sortClass(column) {
    return {
      sortable: true,
      'sort-active': sortColumn.value === column,
    }
  }

  return { sorted, sortColumn, sortDir, toggleSort, sortClass }
}
