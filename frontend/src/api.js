const BASE = import.meta.env.DEV ? '/api' : '/orga/api'

async function request(endpoint, options = {}) {
  const url = `${BASE}/${endpoint}`
  const res = await fetch(url, {
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })

  if (res.status === 401) {
    window.location.hash = '#/login'
    throw new Error('Nicht eingeloggt')
  }

  const contentType = res.headers.get('content-type')
  if (contentType && contentType.includes('application/json')) {
    const data = await res.json()
    if (!res.ok) throw new Error(data.error || 'Fehler')
    return data
  }

  if (!res.ok) throw new Error('Fehler')
  return res
}

export const api = {
  get: (endpoint) => request(endpoint),
  post: (endpoint, data) => request(endpoint, { method: 'POST', body: JSON.stringify(data) }),
  put: (endpoint, data) => request(endpoint, { method: 'PUT', body: JSON.stringify(data) }),
  del: (endpoint) => request(endpoint, { method: 'DELETE' }),
}
