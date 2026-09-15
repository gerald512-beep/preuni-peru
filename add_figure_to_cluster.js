// Adds the missing infographic (Cases/Case8.jpg) to topic 358's root post,
// inserted right after the intro paragraph, before the "Entre 2019 y 2025..."
// paragraph -- matching where it sits in the source material.
require('dotenv').config();
const fs = require('fs');
const path = require('path');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME };
const TOPIC_ID = 358;

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
  const shortUrl = await discourseUpload('Cases/Case8.jpg');
  console.log('Uploaded:', shortUrl);

  const topicRes = await fetch(`${DISCOURSE_URL}/t/${TOPIC_ID}.json`, { headers });
  const topic = await topicRes.json();
  const rootPostId = topic.post_stream.posts.find(p => p.post_number === 1).id;

  const postRes = await fetch(`${DISCOURSE_URL}/posts/${rootPostId}.json`, { headers });
  const rootPost = await postRes.json();
  console.log('Root post id:', rootPost.id);

  const currentRaw = rootPost.raw;
  const marker = 'En su lugar, presentaron documentos emitidos en su país de origen.';
  const idx = currentRaw.indexOf(marker);
  if (idx === -1) throw new Error('Marker paragraph not found in current raw body');
  const insertAt = idx + marker.length;
  const figureBlock = `\n\n![figura infografía](${shortUrl})\n`;
  const newRaw = currentRaw.slice(0, insertAt) + figureBlock + currentRaw.slice(insertAt);

  const putRes = await fetch(`${DISCOURSE_URL}/posts/${rootPost.id}.json`, {
    method: 'PUT',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ post: { raw: newRaw } }),
  });
  const putData = await putRes.json();
  if (!putRes.ok) throw new Error('Update failed: ' + JSON.stringify(putData));
  console.log('Root post updated with figure.');
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
