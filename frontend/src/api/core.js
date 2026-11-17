// Shared helper. Each owner's api file (auth.js, head.js, student.js ...) imports from here.
export const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false';
const BASE = import.meta.env.VITE_API_URL;

// Pretend the network takes a moment, so loading states can be tested.
export const delay = (data) => new Promise((resolve) => setTimeout(() => resolve(data), 300));

// One place that talks to the server: adds the token, parses JSON, throws on errors.
export async function request(path, options = {}) {
  const token = localStorage.getItem('token');
  const res = await fetch(BASE + path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error || 'Request failed');
  return body;
}
