// Public English demo of the question composer (preuni.voluntaria.pe/composer_en).
// Serves composer_en.html plus an asynchronous extraction API; nothing here can
// publish (no Discourse key is needed or used).
//
// Extraction goes through MinerU, whose queue can take minutes, so the page
// starts a job and polls it instead of holding one long request open.
//
// Production: runs on the host bound to the Docker bridge (DEMO_HOST=172.17.0.1)
// as the systemd service preuni-composer-demo; Discourse proxies /composer_en
// to it and rate-limits extractions (PreuniComposerDemoController).
// Local: node composer_demo.js  ->  http://localhost:3001/composer_en
require('dotenv').config();
const express = require('express');
const path = require('path');
const crypto = require('crypto');
const { extractAll } = require('./server');

const app = express();
app.use(express.json({ limit: '12mb' }));

app.get('/composer_en', (_req, res) => res.sendFile(path.join(__dirname, 'composer_en.html')));
app.get('/composer_en/api/status', (_req, res) => res.json({ ready: !!process.env.MINERU_API_KEY }));

const jobs = new Map(); // id -> { state: 'pending'|'done'|'error', result, error, at }
const MAX_RUNNING = 3;
const JOB_TTL_MS = 15 * 60 * 1000;

app.post('/composer_en/api/extract', (req, res) => {
  const m = req.body?.image?.match(/^data:image\/[a-z+.-]+;base64,(.+)$/);
  if (!m) return res.status(400).json({ error: 'Invalid image.' });
  const running = [...jobs.values()].filter(j => j.state === 'pending').length;
  if (running >= MAX_RUNNING) {
    return res.status(429).json({ error: 'Too many extractions in progress. Please try again in a minute.' });
  }
  const id = crypto.randomUUID();
  const job = { state: 'pending', at: Date.now() };
  jobs.set(id, job);
  extractAll(Buffer.from(m[1], 'base64'))
    .then(result => { job.state = 'done'; job.result = result; })
    .catch(err => { job.state = 'error'; job.error = err.message; console.error('[demo extract]', err.message); });
  res.json({ id });
});

app.get('/composer_en/api/extract/:id', (req, res) => {
  const job = jobs.get(req.params.id);
  if (!job) return res.status(404).json({ error: 'Extraction not found (it may have expired).' });
  if (job.state === 'done') return res.json({ state: 'done', result: job.result });
  res.json({ state: job.state, error: job.error });
});

setInterval(() => {
  const now = Date.now();
  for (const [id, job] of jobs) if (now - job.at > JOB_TTL_MS) jobs.delete(id);
}, 60 * 1000).unref();

const PORT = process.env.DEMO_PORT || 3001;
const HOST = process.env.DEMO_HOST || '127.0.0.1';
app.listen(PORT, HOST, () => console.log(`Composer demo -> http://${HOST}:${PORT}/composer_en`));
