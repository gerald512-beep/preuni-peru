// Fixes the two already-published topics whose live solution reply still has
// raw "![](images/xxx.jpg)" markdown (broken -- points at a local MinerU path,
// not an uploaded Discourse URL). Uploads the correct image and edits the
// existing solution post in place with the corrected raw content.
require('dotenv').config();
const fs = require('fs');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME };

const TARGETS = [
  { id: 'p2-MATEMÁTICA-20', topicId: 335 },
  { id: 'p2-MATEMÁTICA-28', topicId: 310 },
];

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

  for (const { id, topicId } of TARGETS) {
    console.log(`--- ${id} (topic ${topicId}) ---`);
    const r = bulkData.find(x => x.id === id);

    const topicRes = await fetch(`${DISCOURSE_URL}/t/${topicId}.json`, { headers });
    const topic = await topicRes.json();
    const solutionPost = topic.post_stream.posts.find(p => p.post_number === 2);
    if (!solutionPost) { console.log('  no solution post found, skipping'); continue; }

    let solRaw = r.solutionBody || '';
    for (let i = 0; i < (r.solutionFigureImages?.length || 0); i++) {
      if (!r.solutionFigureImages[i]) continue;
      const { shortUrl } = await discourseUpload(r.solutionFigureImages[i], `sol_figura_${i + 1}.jpg`);
      solRaw = solRaw.replace(`[FIG:${i}]`, `\n![figura sol ${i + 1}](${shortUrl})\n`);
    }
    solRaw = solRaw.replace(/\[FIG:\d+\]/g, '');

    const putRes = await fetch(`${DISCOURSE_URL}/posts/${solutionPost.id}.json`, {
      method: 'PUT',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ post: { raw: solRaw } }),
    });
    const putData = await putRes.json();
    if (!putRes.ok) { console.log('  FAILED:', JSON.stringify(putData)); continue; }
    console.log('  fixed post', solutionPost.id);
  }
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
