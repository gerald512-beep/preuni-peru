require('dotenv').config({ path: '../.env' });
const fs = require('fs');
const path = require('path');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME };

async function safeJson(res) {
  const text = await res.text();
  try { return JSON.parse(text); } catch { return { __raw: text }; }
}

async function uploadImage(filePath, type) {
  const buf = fs.readFileSync(filePath);
  const form = new FormData();
  form.append('files[]', new Blob([buf], { type: 'image/png' }), path.basename(filePath));
  form.append('type', type);
  form.append('synchronous', 'true');
  const res = await fetch(DISCOURSE_URL + '/uploads.json', { method: 'POST', headers, body: form });
  const data = await safeJson(res);
  if (!res.ok) throw new Error('Upload failed: ' + res.status + ' ' + JSON.stringify(data));
  return data;
}

async function setSetting(name, uploadId) {
  const res = await fetch(DISCOURSE_URL + '/admin/site_settings/' + name + '.json', {
    method: 'PUT',
    headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: name + '=' + uploadId,
  });
  const data = await safeJson(res);
  if (!res.ok) throw new Error('Setting update failed: ' + res.status + ' ' + JSON.stringify(data));
  return data;
}

const MAP = {
  logo: 'logo.png',
  logo_small: 'logo_small.png',
  large_icon: 'large_icon.png',
  favicon: 'favicon.png',
  mobile_logo: 'mobile_logo.png',
  digest_logo: 'digest_logo.png',
};

(async () => {
  for (const [setting, file] of Object.entries(MAP)) {
    console.log('--- ' + setting + ' ---');
    const upload = await uploadImage(file, 'site_setting');
    console.log('  uploaded id=' + upload.id + ' url=' + upload.url);
    await setSetting(setting, upload.id);
    console.log('  setting applied');
  }
  console.log('Done.');
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
