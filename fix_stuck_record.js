// One-off: p3-QUÍMICA-38's topic (170) was created but its solution reply never
// posted (server-side call threw after the main post succeeded, likely hitting
// the upload rate limit). Post the missing solution reply, then stamp the
// bulk_review.json record as published so the resumed batch skips it.
require('dotenv').config();
const fs = require('fs');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME };
const TOPIC_ID = 170;
const RECORD_ID = 'p3-QUÍMICA-38';

async function discourseUpload(dataUrl, filename) {
  const m = dataUrl.match(/^data:([^;]+);base64,(.+)$/);
  const [, mime, b64] = m;
  const buf = Buffer.from(b64, 'base64');
  const form = new FormData();
  form.append('files[]', new Blob([buf], { type: mime }), filename);
  form.append('type', 'composer');
  form.append('synchronous', 'true');
  const res = await fetch(`${DISCOURSE_URL}/uploads.json`, { method: 'POST', headers, body: form });
  if (!res.ok) throw new Error('Upload failed: ' + res.status + ' ' + await res.text());
  const data = await res.json();
  return { shortUrl: data.short_url };
}

(async () => {
  const bulkData = JSON.parse(fs.readFileSync('bulk_review.json', 'utf8'));
  const r = bulkData.find(x => x.id === RECORD_ID);

  let solRaw = r.solutionBody || '';
  for (let i = 0; i < (r.solutionFigureImages?.length || 0); i++) {
    if (!r.solutionFigureImages[i]) continue;
    const { shortUrl } = await discourseUpload(r.solutionFigureImages[i], `sol_figura_${i + 1}.jpg`);
    solRaw = solRaw.replace(`[FIG:${i}]`, `\n![figura sol ${i + 1}](${shortUrl})\n`);
    console.log('uploaded solution figure', i);
  }
  solRaw = solRaw.replace(/\[FIG:\d+\]/g, '');

  const postRes = await fetch(`${DISCOURSE_URL}/posts.json`, {
    method: 'POST',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify({ topic_id: TOPIC_ID, raw: solRaw, preuni_post_type: 'solucion' }),
  });
  const postData = await postRes.json();
  if (!postRes.ok) throw new Error('Post failed: ' + JSON.stringify(postData));
  console.log('Solution posted, post id:', postData.id);

  const stampRes = await fetch(`http://localhost:3000/api/bulk-question/${encodeURIComponent(RECORD_ID)}/publish`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ topicId: TOPIC_ID, topicUrl: `${DISCOURSE_URL}/t/${TOPIC_ID}` }),
  });
  console.log('Stamped as published:', stampRes.ok);
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
