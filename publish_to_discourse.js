// Headless replica of bulk-preview.html's runBulkPublish(), driven against
// the composer server directly (no browser). Talks to localhost:3000, which
// must already be started with DISCOURSE_URL pointed at production.
const BASE = 'http://localhost:3000';

async function main() {
  const batchId = process.argv[2];
  if (!batchId) throw new Error('usage: node tmp_publish_to_prod.js <batchId>');

  const dataRes = await fetch(`${BASE}/api/bulk-data?batch=${encodeURIComponent(batchId)}`);
  const DATA = await dataRes.json();
  if (!Array.isArray(DATA)) throw new Error('bad batch data: ' + JSON.stringify(DATA).slice(0, 200));

  const pending = DATA.filter(r => !r.published && !r.hold && (r.needsReview || []).length === 0);
  const roots = pending.filter(r => r.clusterRole !== 'linked');
  const linked = pending.filter(r => r.clusterRole === 'linked');
  const queue = [...roots, ...linked];

  console.log(`batch=${batchId} total=${DATA.length} pending=${queue.length}`);
  if (!queue.length) { console.log('nothing to publish'); return; }

  function recordToPublishPayload(r) {
    const hasSolucion = (r.solutionBody && r.solutionBody.trim()) || (r.solutionFigureImages || []).length > 0;
    return {
      universidad: r.universidad, tema: r.tema, anio: r.anio, convocatoria: r.convocatoria,
      numero: r.numero, body: r.body, choices: r.choices, choice_images: r.choiceImages || {},
      figure_images: r.figureImages || [], clave: r.clave, tipo_origen: 'Universidad',
      subtemas: r.subtemas || [],
      solucion: hasSolucion ? { body: r.solutionBody || '', figure_images: r.solutionFigureImages || [] } : null,
    };
  }

  async function markPublished(r, topicId, topicUrl) {
    await fetch(`${BASE}/api/bulk-question/${encodeURIComponent(r.id)}/publish?batch=${encodeURIComponent(batchId)}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ topicId, topicUrl }),
    });
  }

  async function publishOne(r) {
    const res = await fetch(`${BASE}/api/publish`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(recordToPublishPayload(r)),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || res.statusText);
    await markPublished(r, data.topic_id, data.topic_url);
    r.published = true; r.topicId = data.topic_id; r.topicUrl = data.topic_url;
    return data.solution_error || null;
  }

  async function publishOneLinked(r, topicId) {
    const hasSolucion = (r.solutionBody && r.solutionBody.trim()) || (r.solutionFigureImages || []).length > 0;
    const payload = {
      topic_id: topicId, body: r.body, choices: r.choices, choice_images: r.choiceImages || {},
      figure_images: r.figureImages || [], clave: r.clave, numero: r.numero,
      solucion: hasSolucion ? { body: r.solutionBody || '', figure_images: r.solutionFigureImages || [] } : null,
    };
    const res = await fetch(`${BASE}/api/publish-linked-question`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || res.statusText);
    await markPublished(r, topicId, data.post_url);
    r.published = true; r.topicId = topicId; r.topicUrl = data.post_url;
    return data.solution_error || null;
  }

  function findClusterRoot(r) {
    return DATA.find(x => x.clusterId === r.clusterId && x.clusterRole === 'root');
  }

  let done = 0, failed = 0;
  for (const r of queue) {
    try {
      let solutionError;
      if (r.clusterRole === 'linked') {
        const root = findClusterRoot(r);
        if (!root || !root.topicId) throw new Error(`cluster root "${r.clusterId}" not yet published`);
        solutionError = await publishOneLinked(r, root.topicId);
      } else {
        solutionError = await publishOne(r);
      }
      done++;
      console.log(`OK ${r.id} -> ${r.topicUrl}`);
      if (solutionError) console.log(`  WARN ${r.id}: solution failed (${solutionError})`);
    } catch (err) {
      failed++;
      console.log(`FAIL ${r.id}: ${err.message}`);
    }
    console.log(`progress ${done + failed}/${queue.length} (${done} ok, ${failed} failed)`);
    await new Promise(res => setTimeout(res, 1500));
  }
  console.log(`DONE batch=${batchId} ok=${done} failed=${failed}`);
}

main().catch(e => { console.error('FATAL', e); process.exit(1); });
