const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { createCsp } = require('./desktop-csp.cjs');

const [mode, ...args] = process.argv.slice(2);
if (!['build', 'dev'].includes(mode)) throw new Error('Expected desktop build or dev.');
const serviceUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const config = { app: { security: { csp: createCsp(serviceUrl, false), devCsp: createCsp(serviceUrl, true) } } };
const binary = path.resolve(__dirname, '..', 'node_modules', '.bin', process.platform === 'win32' ? 'tauri.cmd' : 'tauri');
const result = spawnSync(binary, [mode, '--config', JSON.stringify(config), ...args], { stdio: 'inherit', env: process.env });
if (result.error) throw result.error;
process.exit(result.status ?? 1);
