// One-off monitor: polls /api/bulk-data until all 218 records are published
// (or stop making progress for a while), then prints a final summary.
const TOTAL_EXPECTED = 218;
const MAX_MINUTES = 20;
const POLL_INTERVAL_MS = 15000;
const STALL_LIMIT = 8; // consecutive no-progress polls before giving up early

async function getPublishedCount() {
  const res = await fetch('http://localhost:3000/api/bulk-data');
  const data = await res.json();
  const published = data.filter(r => r.published).length;
  const errors = data.filter(r => r.published === false && r.publishError).length;
  return { published, total: data.length };
}

(async () => {
  const start = Date.now();
  let lastPublished = -1;
  let stallCount = 0;

  while (true) {
    const { published, total } = await getPublishedCount();
    const elapsedMin = ((Date.now() - start) / 60000).toFixed(1);
    console.log(`[${elapsedMin}min] ${published}/${total} published`);

    if (published >= TOTAL_EXPECTED) {
      console.log('DONE: all records published.');
      break;
    }
    if (published === lastPublished) {
      stallCount++;
      if (stallCount >= STALL_LIMIT) {
        console.log(`STALLED: no progress for ${STALL_LIMIT * POLL_INTERVAL_MS / 1000}s, stopping monitor.`);
        break;
      }
    } else {
      stallCount = 0;
    }
    lastPublished = published;

    if ((Date.now() - start) / 60000 > MAX_MINUTES) {
      console.log('TIMEOUT: exceeded max monitor time.');
      break;
    }
    await new Promise(r => setTimeout(r, POLL_INTERVAL_MS));
  }
})();
