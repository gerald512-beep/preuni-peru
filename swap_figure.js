// Replaces the full-page figure in topic 358's root post with the cropped
// diagram-only version (Cases/Case8_cropped.jpg).
require('dotenv').config();
const fs = require('fs');
const path = require('path');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME };
const TOPIC_ID = 358;
const ROOT_POST_ID = 455;

async function discourseUpload(filePath) {
  const buf = fs.readFileSync(filePath);
  const form = new FormData();
  form.append('files[]', new Blob([buf], { type: 'image/jpeg' }), path.basename(filePath));
  form.append('type', 'composer');
  form.append('synchronous', 'true');
  const res = await fetch(`${DISCOURSE_URL}/uploads.json`, { method: 'POST', headers, body: form });
  if (!res.ok) throw new Error('Upload failed: ' + res.status + ' ' + await res.text());
  const data = await res.json();
  return data.short_url;
}

(async () => {
  const newShortUrl = await discourseUpload('Cases/Case8_cropped.jpg');
  console.log('Uploaded cropped image:', newShortUrl);

  const postRes = await fetch(`${DISCOURSE_URL}/posts/${ROOT_POST_ID}.json`, { headers });
  const post = await postRes.json();

  const figureLineRe = /!\[figura infografía\]\(upload:\/\/[^)]+\)/;
  if (!figureLineRe.test(post.raw)) throw new Error('Old figure markdown not found in current raw body');
  const newRaw = post.raw.replace(figureLineRe, `![figura infografía](${newShortUrl})`);

  const putRes = await fetch(`${DISCOURSE_URL}/posts/${ROOT_POST_ID}.json`, {
    method: 'PUT',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ post: { raw: newRaw } }),
  });
  const putData = await putRes.json();
  if (!putRes.ok) throw new Error('Update failed: ' + JSON.stringify(putData));
  console.log('Root post updated with cropped figure.');
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
