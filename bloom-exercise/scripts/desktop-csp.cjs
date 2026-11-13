function createCsp(serviceUrl, development) {
  let url;
  try { url = new URL(serviceUrl); } catch { throw new Error('Set EXPO_PUBLIC_SUPABASE_URL to the Supabase API origin.'); }
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  if (!((url.protocol === 'https:' && !url.port) || (url.protocol === 'http:' && local && url.port))
    || url.username || url.password || url.search || url.hash || (url.pathname !== '/' && url.pathname !== '')) {
    throw new Error('Supabase must use an HTTPS origin, or a local HTTP origin with an explicit port.');
  }
  const socketOrigin = `${url.protocol === 'https:' ? 'wss:' : 'ws:'}//${url.host}`;
  const connections = ["'self'", 'ipc:', 'http://ipc.localhost', url.origin, socketOrigin];
  if (development) connections.push('http://localhost:8081', 'ws://localhost:8081', 'http://127.0.0.1:8081', 'ws://127.0.0.1:8081');
  return [
    "default-src 'self'", "script-src 'self'", "style-src 'self' 'unsafe-inline'",
    "img-src 'self' asset: http://asset.localhost data: blob:",
    "font-src 'self' asset: http://asset.localhost data:",
    `connect-src ${connections.join(' ')}`,
    "object-src 'none'", "base-uri 'none'", "frame-src 'none'", "form-action 'none'",
  ].join('; ');
}
module.exports = { createCsp };
