// General version of fix_stuck_record.js: for records whose topic was already
// created (visible via a "title already used" error pointing at an existing
// topic) but never got stamped as published -- because a later step (solution
// reply upload) hit the rate limit -- complete the missing solution reply (if
// any) and stamp the record. Safe to re-run: skips if already published.
require('dotenv').config();
const fs = require('fs');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://127.0.0.1:8080';
const headers = { 'Api-Key': process.env.DISCOURSE_API_KEY, 'Api-Username': process.env.DISCOURSE_API_USERNAME };

const STUCK = [
  { id: 'p1-RAZONAMIENTO_MATEMÁTICO-18', topicId: 196 },
  { id: 'p2-MATEMÁTICA-12', topicId: 305 },
  { id: 'p2-MATEMÁTICA-16', topicId: 248 },
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

async function getTopic(topicId) {
  const res = await fetch(`${DISCOURSE_URL}/t/${topicId}.json`, { headers });
  if (!res.ok) throw new Error('Topic fetch failed: ' + res.status);
  return res.json();
}

(async () => {
  const bulkData = JSON.parse(fs.readFileSync('bulk_review.json', 'utf8'));

  for (const { id, topicId } of STUCK) {
    console.log(`--- ${id} (topic ${topicId}) ---`);
    const r = bulkData.find(x => x.id === id);
    if (!r) { console.log('  not found in bulk data, skipping'); continue; }

    const topic = await getTopic(topicId);
    const hasSolution = (r.solutionBody && r.solutionBody.trim()) || (r.solutionFigureImages || []).length;

    if (topic.posts_count < 2 && hasSolution) {
      let solRaw = r.solutionBody || '';
      for (let i = 0; i < (r.solutionFigureImages?.length || 0); i++) {
        if (!r.solutionFigureImages[i]) continue;
        const { shortUrl } = await discourseUpload(r.solutionFigureImages[i], `sol_figura_${i + 1}.jpg`);
        solRaw = solRaw.replace(`[FIG:${i}]`, `\n![figura sol ${i + 1}](${shortUrl})\n`);
      }
      solRaw = solRaw.replace(/\[FIG:\d+\]/g, '');

      const postRes = await fetch(`${DISCOURSE_URL}/posts.json`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ topic_id: topicId, raw: solRaw, preuni_post_type: 'solucion' }),
      });
      const postData = await postRes.json();
      if (!postRes.ok) { console.log('  FAILED posting solution:', JSON.stringify(postData)); continue; }
      console.log('  solution posted, post id:', postData.id);
    } else {
      console.log('  posts_count=' + topic.posts_count + ', no missing solution to post');
    }

    const stampRes = await fetch(`http://localhost:3000/api/bulk-question/${encodeURIComponent(id)}/publish`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ topicId, topicUrl: `${DISCOURSE_URL}/t/${topicId}` }),
    });
    console.log('  stamped as published:', stampRes.ok);

    await new Promise(res => setTimeout(res, 1500));
  }
})().catch(e => { console.error('ERROR:', e.message); process.exitCode = 1; });
