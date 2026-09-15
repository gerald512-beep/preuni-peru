require('dotenv').config();
const express   = require('express');
const AdmZip    = require('adm-zip');
const { execSync } = require('child_process');
const os   = require('os');
const path = require('path');
const fs   = require('fs');

const app = express();
app.use(express.json({ limit: '20mb' }));
app.get('/favicon.ico', (_req, res) => res.sendStatus(204));
app.use(express.static(__dirname));

const MINERU  = 'https://mineru.net';
const API_KEY = process.env.MINERU_API_KEY;

const DISCOURSE_URL      = process.env.DISCOURSE_URL || 'http://localhost:8080';
const DISCOURSE_API_KEY  = process.env.DISCOURSE_API_KEY;
const DISCOURSE_USERNAME = process.env.DISCOURSE_API_USERNAME || 'gerald';

// Categories are looked up by name (universidad = parent category, tema = subcategory)
// via the Discourse API instead of hardcoded IDs — IDs differ between local and
// production instances, and this map had already drifted out of sync by hand once.
let categoryCache = null; // { universidad: { tema: id } }

async function loadCategoryMap() {
  const res = await fetch(`${DISCOURSE_URL}/site.json`, {
    headers: { 'Api-Key': DISCOURSE_API_KEY, 'Api-Username': DISCOURSE_USERNAME },
  });
  if (!res.ok) throw new Error(`Failed to load categories: ${res.status}`);
  const { categories } = await res.json();
  const byId = new Map(categories.map(c => [c.id, c]));
  const map = {};
  for (const c of categories) {
    if (!c.parent_category_id) continue;
    const parent = byId.get(c.parent_category_id);
    if (!parent) continue;
    (map[parent.name] ??= {})[c.name] = c.id;
  }
  return map;
}

async function getCategoryId(universidad, tema) {
  if (!categoryCache) categoryCache = await loadCategoryMap();
  let id = categoryCache[universidad]?.[tema];
  if (id === undefined) categoryCache = await loadCategoryMap(); // refresh once, in case it was just added
  return categoryCache[universidad]?.[tema];
}

async function getCategoryIdsForUniversidad(universidad) {
  if (!categoryCache) categoryCache = await loadCategoryMap();
  return new Set(Object.values(categoryCache[universidad] || {}));
}

// ── Image preprocessing (Python / PIL) ──────────────────────────────────────
function pyProcess(buf, pyCode) {
  const tmpIn  = path.join(os.tmpdir(), `preuni_in_${Date.now()}.jpg`);
  const tmpOut = path.join(os.tmpdir(), `preuni_out_${Date.now()}.jpg`);
  fs.writeFileSync(tmpIn, buf);
  const script = path.join(os.tmpdir(), `preuni_py_${Date.now()}.py`);
  fs.writeFileSync(script, pyCode.replace(/__IN__/g, tmpIn).replace(/__OUT__/g, tmpOut));
  try { execSync(`python "${script}"`, { timeout: 20000 }); } finally { try { fs.unlinkSync(script); } catch {} }
  const out = fs.existsSync(tmpOut) ? fs.readFileSync(tmpOut) : buf;
  try { fs.unlinkSync(tmpIn); fs.unlinkSync(tmpOut); } catch {}
  return out;
}

// Scale up if shorter side < minSide
function upscaleImage(buf, minSide = 1200) {
  return pyProcess(buf, `
from PIL import Image
img = Image.open(r"__IN__")
if img.mode != 'RGB':
    img = img.convert('RGB')
w, h = img.size
if min(w, h) < ${minSide}:
    scale = ${minSide} / min(w, h)
    img = img.resize((int(w*scale), int(h*scale)), Image.LANCZOS)
img.save(r"__OUT__", "JPEG", quality=95)
`);
}

// Crop the bottom 12% of the image (choice zone) and CENTER it in a 1200x1200 canvas.
// Key: MinerU pipeline fails when text is pasted at y=0 edge — centering solves it.
function cropChoiceZone(buf) {
  return pyProcess(buf, `
from PIL import Image
img = Image.open(r"__IN__")
w, h = img.size
crop = img.crop((0, int(h * 0.88), w, h))
cw, ch = crop.size
canvas_size = max(cw, 1200)
canvas = Image.new('RGB', (canvas_size, canvas_size), (255, 255, 255))
y_off = (canvas_size - ch) // 2
canvas.paste(crop, (0, y_off))
canvas.save(r"__OUT__", "JPEG", quality=95)
`);
}

// ── MinerU Standard API ──────────────────────────────────────────────────────
async function mineruParse(imgBuf, modelVersion = 'pipeline') {
  const authJSON = { 'Authorization': `Bearer ${API_KEY}`, 'Content-Type': 'application/json' };

  const batchRes = await fetch(`${MINERU}/api/v4/file-urls/batch`, {
    method: 'POST', headers: authJSON,
    body: JSON.stringify({
      files:          [{ name: 'page.png' }],
      model_version:  modelVersion,
      enable_formula: true,
      enable_table:   true,
      is_ocr:         true
    })
  });
  const batch = await batchRes.json();
  if (batch.code !== 0) throw new Error(`MinerU batch: ${batch.msg}`);
  const { batch_id, file_urls } = batch.data;
  console.log('[MinerU] batch_id:', batch_id);

  const putRes = await fetch(file_urls[0], { method: 'PUT', body: imgBuf });
  if (!putRes.ok) throw new Error(`MinerU upload: ${putRes.status}`);

  for (let i = 0; i < 40; i++) {
    await new Promise(r => setTimeout(r, 3000));
    const poll   = await (await fetch(`${MINERU}/api/v4/extract-results/batch/${batch_id}`,
      { headers: { 'Authorization': `Bearer ${API_KEY}` } })).json();
    const result = poll.data?.extract_result?.[0];
    const state  = result?.state;
    if (i % 5 === 0) console.log(`[MinerU] poll ${i+1}: ${state}`);
    if (state === 'done' && result.full_zip_url) return extractZip(result.full_zip_url);
    if (state === 'failed') throw new Error(`MinerU failed: ${result.err_msg}`);
  }
  throw new Error('MinerU: timeout');
}

// ── Agent API fallback (no key) ──────────────────────────────────────────────
async function agentParse(imgBuf) {
  const initRes = await fetch(`${MINERU}/api/v1/agent/parse/file`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ file_name: 'page.png', enable_formula: true })
  });
  const init = await initRes.json();
  if (init.code !== 0) throw new Error(`MinerU agent: ${init.msg}`);
  await fetch(init.data.file_url, { method: 'PUT', body: imgBuf });

  for (let i = 0; i < 40; i++) {
    await new Promise(r => setTimeout(r, 3000));
    const poll = await (await fetch(`${MINERU}/api/v1/agent/parse/${init.data.task_id}`)).json();
    const { state, markdown_url } = poll.data ?? {};
    if (state === 'done' && markdown_url)
      return { markdown: await (await fetch(markdown_url)).text(), figures: {}, contentList: null };
    if (state === 'failed') throw new Error('MinerU agent: failed');
  }
  throw new Error('MinerU agent: timeout');
}

// ── ZIP extraction ───────────────────────────────────────────────────────────
async function extractZip(zipUrl) {
  const buf = Buffer.from(await (await fetch(zipUrl)).arrayBuffer());
  const zip = new AdmZip(buf);
  let markdown = '', contentList = null;
  const figures = {};

  for (const entry of zip.getEntries()) {
    const name = entry.entryName.replace(/\\/g, '/');
    if (/full\.md$/i.test(name))                             markdown    = entry.getData().toString('utf8');
    if (/_content_list\.json$/i.test(name) && !/_v2/.test(name)) {
      try { contentList = JSON.parse(entry.getData().toString('utf8')); } catch {}
    }
    if (/\.(jpg|jpeg|png)$/i.test(name)) {
      figures[name.split('/').pop()] = 'data:image/jpeg;base64,' + entry.getData().toString('base64');
    }
  }
  console.log('[MinerU] md:', markdown.length, 'B | figs:', Object.keys(figures).length, '| cl:', contentList?.length ?? 0);
  return { markdown, figures, contentList };
}

// ── Main extraction with choice-boost fallback ───────────────────────────────
async function extractAll(rawBuf) {
  const buf = upscaleImage(rawBuf);

  const pass1 = API_KEY ? await mineruParse(buf) : await agentParse(buf);
  const result = parseResult(pass1);

  const filled = Object.values(result.choices).filter(v => v.trim()).length;
  if (filled < 5) {
    console.log(`[extract] Only ${filled} choices — boost1: bottom-12% crop`);
    const crop12Buf = cropChoiceZone(buf);  // 12% centered in 1200×1200
    try {
      const boost1 = API_KEY ? await mineruParse(crop12Buf, 'pipeline') : await agentParse(crop12Buf);
      const boost1Result = parseResult(boost1);
      for (const k of 'ABCDE') {
        if (!result.choices[k] && boost1Result.choices[k]) result.choices[k] = boost1Result.choices[k];
      }
      console.log('[extract] After boost1:', Object.values(result.choices).filter(v=>v).length, 'choices');
    } catch (e) { console.log('[extract] boost1 error:', e.message); }

    // Second boost: 20% crop — picks up choices that sit just above the 12% boundary
    const filled2 = Object.values(result.choices).filter(v => v.trim()).length;
    if (filled2 < 5) {
      console.log(`[extract] Still ${filled2}/5 — boost2: bottom-20% crop`);
      const crop20Buf = pyProcess(buf, `
from PIL import Image
img = Image.open(r"__IN__")
w, h = img.size
crop = img.crop((0, int(h * 0.80), w, h))
cw, ch = crop.size
canvas_size = max(cw, 1200)
canvas = Image.new('RGB', (canvas_size, canvas_size), (255, 255, 255))
y_off = (canvas_size - ch) // 2
canvas.paste(crop, (0, y_off))
canvas.save(r"__OUT__", "JPEG", quality=95)
`);
      try {
        const boost2 = API_KEY ? await mineruParse(crop20Buf, 'pipeline') : await agentParse(crop20Buf);
        const boost2Result = parseResult(boost2);
        for (const k of 'ABCDE') {
          if (!result.choices[k] && boost2Result.choices[k]) result.choices[k] = boost2Result.choices[k];
        }
        console.log('[extract] After boost2:', Object.values(result.choices).filter(v=>v).length, 'choices');
      } catch (e) { console.log('[extract] boost2 error:', e.message); }
    }

    // Last resort: Agent VLM on full image
    const filled3 = Object.values(result.choices).filter(v => v.trim()).length;
    if (filled3 < 3) {
      console.log('[extract] Trying Agent VLM on full image as last resort');
      try {
        const agent = await agentParse(buf);
        const agentResult = parseResult(agent);
        for (const k of 'ABCDE') {
          if (!result.choices[k] && agentResult.choices[k]) result.choices[k] = agentResult.choices[k];
        }
        console.log('[extract] After Agent boost:', Object.values(result.choices).filter(v=>v).length, 'choices');
      } catch (e) { console.log('[extract] Agent boost error:', e.message); }
    }
  }

  return result;
}

// ── Parse ZIP result → question JSON ────────────────────────────────────────
function parseResult({ markdown, figures, contentList }) {
  // Resolve figure references → base64 data URLs
  let md = markdown;
  for (const [name, dataUrl] of Object.entries(figures)) {
    md = md.replace(new RegExp(`!\\[.*?\\]\\([^)]*${escRe(name)}[^)]*\\)`, 'g'), `![fig](${dataUrl})`);
  }

  // Identify figure types from content_list (exclude equations from has_figure)
  const imagePaths = new Set(
    (contentList ?? [])
      .filter(item => item.type === 'image' || item.type === 'figure')
      .map(item => item.img_path?.split('/').pop())
      .filter(Boolean)
  );
  const has_figure = [...Object.keys(figures)].some(k => imagePaths.has(k)) ||
                     /!\[.*?\]\(data:image/.test(md) ||
                     /<!--\s*image\s*-->/i.test(md);

  // Extract question number before stripping it
  const numMatch = md.match(/^\s*\*{0,2}(\d+)[\.\)]\*{0,2}\s*/m);
  const numero = numMatch ? parseInt(numMatch[1], 10) : null;

  // Normalize: remove placeholders, section headers, question number
  md = md
    .replace(/<!--\s*image\s*-->/gi, '')
    .replace(/^#{1,4}\s.*$/mg, '')
    .replace(/^\s*\*{0,2}\d+[\.\)]\*{0,2}\s*/m, '')
    .trim();

  // Split body / choices
  const firstChoice = findFirstChoice(md);
  // firstChoice === -1 → no choices; === 0 → choices at start; > 0 → body before choices
  const bodyRaw  = firstChoice > 0 ? md.slice(0, firstChoice).trim() : (firstChoice < 0 ? md : '');
  const choiceRaw = firstChoice >= 0 ? md.slice(firstChoice) : '';

  const choices        = parseChoices(choiceRaw);
  // Replace inline figure references with [FIG:N] markers, preserving position
  const bodyFigures = [];
  const bodyText = bodyRaw
    .replace(/!\[.*?\]\((data:image\/[^)]+)\)/g, (_, url) => {
      const idx = bodyFigures.length;
      bodyFigures.push(url);
      return `[FIG:${idx}]`;
    })
    .replace(/\n{3,}/g, '\n\n').trim();

  const choiceFigures  = Object.values(choices).some(v => /!\[.*?\]\(/.test(v));
  const choices_are_images = choiceFigures &&
    Object.values(choices).every(v => !v.trim() || /^\s*!\[.*?\]\(/.test(v.trim()));

  return {
    numero,
    body:            bodyText,
    choices,
    clave:           null,
    convocatoria:    null,
    universidad:     null,
    tema:            null,
    subtemas:        [],
    has_figure,
    choices_are_images,
    figure_images:   bodyFigures
  };
}

// ── Helpers ──────────────────────────────────────────────────────────────────
const { findFirstChoice, parseChoices, escRe } = require('./parse-helpers');

function extractFigureUrls(text) {
  const urls = [], re = /!\[.*?\]\((data:image\/[^)]+)\)/g;
  let m; while ((m = re.exec(text)) !== null) urls.push(m[1]);
  return urls;
}

// ── Routes ───────────────────────────────────────────────────────────────────
app.get('/api/status', (_req, res) =>
  res.json({ ready: true, engine: API_KEY ? 'MinerU Standard' : 'MinerU Agent' }));

// Debug: raw markdown + content_list
app.post('/api/extract-raw', async (req, res) => {
  const match = req.body.image?.match(/^data:([^;]+);base64,(.+)$/);
  if (!match) return res.status(400).json({ error: 'Invalid' });
  const buf = Buffer.from(match[2], 'base64');
  try {
    const up = upscaleImage(buf);
    const { markdown, figures, contentList } = API_KEY ? await mineruParse(up) : await agentParse(up);
    res.json({ markdown, figure_keys: Object.keys(figures), content_list: contentList });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/extract', async (req, res) => {
  const match = req.body.image?.match(/^data:([^;]+);base64,(.+)$/);
  if (!match) return res.status(400).json({ error: 'Invalid image format' });
  const buffer = Buffer.from(match[2], 'base64');
  try {
    res.json(await extractAll(buffer));
  } catch (err) {
    console.error('Extract error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── DISCOURSE PUBLISH ──────────────────────────────────────────────────────
// Ensure a tag exists with exact name before posting (prevents Discourse normalization N°X → nX)
async function ensureTag(tagName) {
  try {
    await fetch(`${DISCOURSE_URL}/admin/tags`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Api-Key': DISCOURSE_API_KEY,
        'Api-Username': DISCOURSE_USERNAME,
      },
      body: JSON.stringify({ tag: { name: tagName } }),
    });
  } catch {}  // 422 = already exists — ignore
}

async function discourseUpload(dataUrl, filename) {
  const m = dataUrl.match(/^data:([^;]+);base64,(.+)$/);
  if (!m) throw new Error('Invalid image data for upload');
  const [, mime, b64] = m;
  const buf = Buffer.from(b64, 'base64');
  const form = new FormData();
  form.append('files[]', new Blob([buf], { type: mime }), filename);
  form.append('type', 'composer');
  form.append('synchronous', 'true');
  const res = await fetch(`${DISCOURSE_URL}/uploads.json`, {
    method: 'POST',
    headers: { 'Api-Key': DISCOURSE_API_KEY, 'Api-Username': DISCOURSE_USERNAME },
    body: form,
  });
  if (!res.ok) throw new Error(`Upload failed: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return { shortUrl: data.short_url, url: data.url };
}

function buildTitle(body, fallback) {
  // Drop math spans entirely rather than unwrapping them — raw LaTeX commands
  // left in a title (\boxed, \equiv, \left…) trip Discourse's title-quality
  // check ("most words contain the same letters over and over"), since
  // stripped-down math tends to collapse into repeated single letters (p, q, x).
  const clean = body
    .replace(/\$\$[\s\S]*?\$\$/g, ' ')
    .replace(/\$[^$]*\$/g, ' ')
    .replace(/\[FIG:\d+\]/g, '')
    .replace(/\\[a-zA-Z]+/g, ' ')
    .replace(/[{}^_]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  const title = clean.length > 80 ? clean.slice(0, 80) + '…' : clean;
  // Short bare-instruction phrases ("Halle el valor de", "Calcule...") still trip
  // Discourse's title-entropy check even with zero LaTeX residue -- their word
  // count is too low for the check to read as "real" text. 15 chars wasn't a high
  // enough bar; raised after ptraslado-CÁLCULO_INTEGRAL-35 got rejected at 18 chars.
  return title.length >= 30 ? title : (fallback || title || 'Pregunta');
}

function buildRaw(body, choices, choiceUrls) {
  let raw = body.trim() + '\n\n';
  ['A','B','C','D','E'].forEach(l => {
    raw += choiceUrls[l]
      ? `**(${l})** ![alternativa ${l}](${choiceUrls[l]})\n`
      : `**(${l})** ${choices[l]}\n`;
  });
  return raw;
}

app.post('/api/publish', async (req, res) => {
  try {
    const { universidad, tema, anio, convocatoria, numero, body, choices,
            choice_images, figure_images, source_image, clave,
            tipo_origen, subtemas, solucion } = req.body;

    if (!universidad || !tema || !body || !clave)
      return res.status(400).json({ error: 'Faltan campos requeridos.' });

    const categoryId = await getCategoryId(universidad, tema);
    if (!categoryId)
      return res.status(400).json({ error: `Categoría no encontrada: ${universidad} / ${tema}` });

    // Ensure N°X tag + subtema tags exist and collect all tags
    const tags = [];
    if (numero) {
      const tagName = `N°${numero}`;
      await ensureTag(tagName);
      tags.push(tagName);
    }
    for (const sub of (subtemas || [])) {
      await ensureTag(sub);
      tags.push(sub);
    }

    // Build structured convocatoria: "2024-I Ordinario" or just "2024"
    const convStr = [anio, convocatoria].filter(Boolean).join('-');

    // Upload figures, replace [FIG:N] markers
    let resolvedBody = body;
    for (let i = 0; i < (figure_images?.length || 0); i++) {
      if (!figure_images[i]) continue;
      const { shortUrl } = await discourseUpload(figure_images[i], `figura_${i + 1}.jpg`);
      resolvedBody = resolvedBody.replace(`[FIG:${i}]`, `\n![figura ${i + 1}](${shortUrl})\n`);
    }
    resolvedBody = resolvedBody.replace(/\[FIG:\d+\]/g, '');

    // Upload choice images
    const choiceUrls = {};
    for (const [l, dataUrl] of Object.entries(choice_images || {})) {
      if (!dataUrl) continue;
      const { shortUrl } = await discourseUpload(dataUrl, `alternativa_${l}.jpg`);
      choiceUrls[l] = shortUrl;
    }

    // Upload source image (archival)
    if (source_image) {
      const { url } = await discourseUpload(source_image, `fuente_${Date.now()}.jpg`);
      resolvedBody += `\n<!-- preuni:source:${url} -->`;
    }

    const fallbackTitle = [tema, numero ? `N°${numero}` : null].filter(Boolean).join(' — ') || 'Pregunta';
    const title = buildTitle(resolvedBody, fallbackTitle);
    const raw   = buildRaw(resolvedBody, choices, choiceUrls);

    // Custom fields go in the POST body — PUT /t/:id silently drops them
    const postRes = await fetch(`${DISCOURSE_URL}/posts.json`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Api-Key': DISCOURSE_API_KEY,
        'Api-Username': DISCOURSE_USERNAME,
      },
      body: JSON.stringify({
        title, raw, category: categoryId, tags,
        topic_custom_fields: {
          preuni_clave:        clave,
          preuni_convocatoria: convStr,
          preuni_numero:       String(numero || ''),
          preuni_universidad:  universidad,
          preuni_tema:         tema,
          preuni_tipo_origen:  tipo_origen || 'Universidad',
        },
      }),
    });

    if (!postRes.ok) {
      const err = await postRes.json().catch(() => ({}));
      throw new Error(err.errors?.join(', ') || `Discourse error: ${postRes.status}`);
    }

    const post = await postRes.json();
    const topicId  = post.topic_id;
    const topicUrl = `${DISCOURSE_URL}/t/${post.topic_slug}/${topicId}`;

    // Create solution reply if provided. The main topic is already live at this
    // point, so a failure here must NOT be swallowed silently (it was -- this
    // fetch's result went unchecked, which let several solution replies vanish
    // without any error surfacing, only caught later by an out-of-band audit).
    let solutionError = null;
    if (solucion?.body || solucion?.figure_images?.length) {
      let solRaw = solucion.body || '';
      for (let i = 0; i < (solucion.figure_images?.length || 0); i++) {
        if (!solucion.figure_images[i]) continue;
        const { shortUrl } = await discourseUpload(solucion.figure_images[i], `sol_figura_${i + 1}.jpg`);
        solRaw = solRaw.replace(`[FIG:${i}]`, `\n![figura sol ${i + 1}](${shortUrl})\n`);
      }
      solRaw = solRaw.replace(/\[FIG:\d+\]/g, '');

      const solRes = await fetch(`${DISCOURSE_URL}/posts.json`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Api-Key': DISCOURSE_API_KEY,
          'Api-Username': DISCOURSE_USERNAME,
        },
        body: JSON.stringify({
          topic_id: topicId,
          raw: solRaw,
          preuni_post_type: 'solucion',
        }),
      });
      if (!solRes.ok) {
        const err = await solRes.json().catch(() => ({}));
        solutionError = err.errors?.join(', ') || `Discourse error: ${solRes.status}`;
        console.error(`Solution reply failed for topic ${topicId}:`, solutionError);
      }
    }

    res.json({ topic_url: topicUrl, topic_id: topicId, solution_error: solutionError });

  } catch (err) {
    console.error('Publish error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/check-duplicate', async (req, res) => {
  try {
    const { titulo, universidad, anio, convocatoria, numero } = req.body;
    const headers = { 'Api-Key': DISCOURSE_API_KEY, 'Api-Username': DISCOURSE_USERNAME };
    const uniCatIds = await getCategoryIdsForUniversidad(universidad);
    let match = null;

    // Strategy 1: search by N°X tag within universidad categories
    if (numero && uniCatIds.size) {
      const tagRes = await fetch(
        `${DISCOURSE_URL}/tag/${encodeURIComponent('N°' + numero)}/l/latest.json`,
        { headers }
      );
      if (tagRes.ok) {
        const tagData = await tagRes.json();
        match = (tagData.topic_list?.topics || []).find(t => {
          if (!uniCatIds.has(t.category_id)) return false;
          if (!anio) return true;
          return t.title?.includes(anio) || t.title?.includes(String(anio).slice(-2));
        });
      }
    }

    // Strategy 2: title search as fallback
    if (!match && titulo) {
      const q = titulo.substring(0, 50);
      const searchRes = await fetch(
        `${DISCOURSE_URL}/search.json?q=${encodeURIComponent(q)}`,
        { headers }
      );
      if (searchRes.ok) {
        const sd = await searchRes.json();
        match = (sd.topics || []).find(t => uniCatIds.has(t.category_id));
      }
    }

    res.json({
      duplicate: !!match,
      topic_url: match ? `${DISCOURSE_URL}/t/${match.slug}/${match.id}` : null,
    });
  } catch {
    res.json({ duplicate: false });
  }
});

// ── Bulk pipeline: composer edit mode for flagged questions ────────────────
const BULK_REVIEW_PATH = path.join(__dirname, 'bulk_review.json');

function readBulkReview() {
  return JSON.parse(fs.readFileSync(BULK_REVIEW_PATH, 'utf8'));
}

app.get('/api/bulk-data', (req, res) => {
  try {
    res.set('Access-Control-Allow-Origin', '*');
    res.json(readBulkReview());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/bulk-question/:id', (req, res) => {
  try {
    const data = readBulkReview();
    const q = data.find(r => r.id === req.params.id);
    if (!q) return res.status(404).json({ error: 'No encontrado en bulk_review.json' });
    res.json(q);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/bulk-question/:id', (req, res) => {
  try {
    const data = readBulkReview();
    const idx = data.findIndex(r => r.id === req.params.id);
    if (idx === -1) return res.status(404).json({ error: 'No encontrado en bulk_review.json' });

    const { body, choices, choiceImages, figureImages, clave, tema, subtemas, solutionBody, solutionFigureImages } = req.body;
    if (body !== undefined) data[idx].body = body;
    if (choices !== undefined) data[idx].choices = choices;
    // Merge per-letter, never replace wholesale — the composer's choiceImages
    // state defaults every letter to null, so a save that only touched A/B
    // must not blank out an already-saved C/D/E.
    if (choiceImages !== undefined) {
      data[idx].choiceImages = data[idx].choiceImages || {};
      for (const l of ['A','B','C','D','E']) {
        if (choiceImages[l]) data[idx].choiceImages[l] = choiceImages[l];
      }
    }
    if (figureImages !== undefined) data[idx].figureImages = figureImages;
    if (clave !== undefined) data[idx].clave = clave;
    if (tema !== undefined) data[idx].tema = tema;
    if (subtemas !== undefined) data[idx].subtemas = subtemas;
    if (solutionBody !== undefined) data[idx].solutionBody = solutionBody;
    if (solutionFigureImages !== undefined) data[idx].solutionFigureImages = solutionFigureImages;

    // A manual fix clears any review flags the admin just addressed —
    // re-validate the basics so a half-fixed row doesn't silently pass.
    // A choice counts as present if it has text OR an assigned image.
    const missingChoices = ['A','B','C','D','E'].filter(l => !data[idx].choices[l]?.trim() && !data[idx].choiceImages?.[l]);
    const stillBroken = [];
    if (missingChoices.length) stillBroken.push(`missing_choices:${missingChoices.join(',')}`);
    if (!data[idx].clave) stillBroken.push('oa_unmatched');
    if (data[idx].oaMethod !== 'table' && !data[idx].solutionBody?.trim()) stillBroken.push('worked_solution_not_found');
    data[idx].needsReview = stillBroken;
    data[idx].manuallyFixed = true;

    fs.writeFileSync(BULK_REVIEW_PATH, JSON.stringify(data, null, 2));
    res.json({ ok: true, needsReview: data[idx].needsReview });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Records publish result against a bulk_review.json row after the client has
// already called /api/publish. Kept separate from the PUT handler above so
// stamping publish status never flips manuallyFixed / needsReview.
app.post('/api/bulk-question/:id/publish', (req, res) => {
  try {
    const data = readBulkReview();
    const idx = data.findIndex(r => r.id === req.params.id);
    if (idx === -1) return res.status(404).json({ error: 'No encontrado en bulk_review.json' });

    const { topicId, topicUrl } = req.body;
    data[idx].published = true;
    data[idx].topicId = topicId;
    data[idx].topicUrl = topicUrl;
    data[idx].publishedAt = new Date().toISOString();

    fs.writeFileSync(BULK_REVIEW_PATH, JSON.stringify(data, null, 2));
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`PreUni composer → http://localhost:${PORT}/question-composer-prototype.html  [${API_KEY ? 'MinerU Standard' : 'MinerU Agent'}]`));
