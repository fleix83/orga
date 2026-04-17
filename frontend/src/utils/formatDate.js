const MONTHS = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
]

/**
 * Formats an ISO date string (YYYY-MM-DD) to German long form: "12. März 2026".
 * Returns an em-dash for empty/invalid values.
 */
export function formatDate(value) {
  if (!value) return '–'
  const s = String(value).slice(0, 10)
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!m) return value
  const year = m[1]
  const month = parseInt(m[2], 10)
  const day = parseInt(m[3], 10)
  if (month < 1 || month > 12) return value
  return `${day}. ${MONTHS[month - 1]} ${year}`
}
