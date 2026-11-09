/**
 * Labels for customers and bookings linked to a task (@-Erwähnungen).
 * A link carries either `customer_id` or `order_id` plus the joined name fields.
 */

/** "12.11.2026" for an ISO date; empty string for empty values. */
export function shortDate(value) {
  if (!value) return ''
  const m = String(value).slice(0, 10).match(/^(\d{4})-(\d{2})-(\d{2})$/)
  return m ? `${m[3]}.${m[2]}.${m[1]}` : String(value)
}

// Collapses stray whitespace in stored names ("Liyo " + "Ketema").
export function customerName(first, last) {
  return `${first || ''} ${last || ''}`.replace(/\s+/g, ' ').trim()
}

export function orderLabel(order) {
  return order.order_number
    ? `Buchung ${order.order_number}`
    : `Buchung ${shortDate(order.order_date)}`
}

export function linkKey(link) {
  return link.customer_id ? `c${link.customer_id}` : `o${link.order_id}`
}

export function linkLabel(link) {
  if (link.customer_id) return customerName(link.customer_first_name, link.customer_last_name)
  return orderLabel(link)
}

export function linkTitle(link) {
  if (link.customer_id) return 'Kunde'
  const name = customerName(link.order_customer_first_name, link.order_customer_last_name)
  return [name, shortDate(link.order_date)].filter(Boolean).join(' · ')
}

/** Mention candidates for the @-autocomplete, built from the customer and booking lists. */
export function buildCandidates(customers, orders) {
  const result = []
  for (const c of customers) {
    result.push({
      key: `c${c.id}`,
      type: 'customer',
      label: customerName(c.first_name, c.last_name),
      sub: c.customer_number ? `Nr. ${c.customer_number}` : '',
      link: { customer_id: c.id, customer_first_name: c.first_name, customer_last_name: c.last_name },
    })
  }
  for (const o of orders) {
    const name = customerName(o.customer_first_name, o.customer_last_name)
    result.push({
      key: `o${o.id}`,
      type: 'order',
      label: orderLabel(o),
      sub: [name, shortDate(o.order_date), o.service_names].filter(Boolean).join(' · '),
      link: {
        order_id: o.id,
        order_number: o.order_number,
        order_date: o.order_date,
        order_customer_first_name: o.customer_first_name,
        order_customer_last_name: o.customer_last_name,
      },
    })
  }
  return result
}
