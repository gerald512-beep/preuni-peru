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
function findFirstChoice(text) {
  // Allow zero spaces after ) — MinerU sometimes outputs "A)-4" without space
  const m = /(?:^|\n)\s*([A-E])\)/m.exec(text);
  if (!m) return -1;
  return m.index + (m[0].startsWith('\n') ? 1 : 0);
}

function extractFigureUrls(text) {
  const urls = [], re = /!\[.*?\]\((data:image\/[^)]+)\)/g;
  let m; while ((m = re.exec(text)) !== null) urls.push(m[1]);
  return urls;
}

// Standard two-column exam layout: A+D / B+E / C
const NEXT_AFTER_TWOCOL = { A: 'B', B: 'C', C: null };

function parseChoices(raw) {
  const choices = { A: '', B: '', C: '', D: '', E: '' };
  if (!raw.trim()) return choices;

  let current = null;
  let nextExpected = null;  // next unlabeled slot after a two-column row

  for (const line of raw.split('\n')) {
    const stripped = line.trim();
    if (!stripped) { current = null; continue; }

    // Display math delimiter line ($$) or inline display math ($$...$$)
    if (stripped === '$$') continue;
    if (/^\$\$/.test(stripped)) {
      // Inline display math with content: $$content$$
      const inner = stripped.replace(/^\$\$|\$\$$/g, '').trim();
      if (inner && nextExpected && !choices[nextExpected]) {
        choices[nextExpected] = '$' + inner + '$';
        current = nextExpected;
        nextExpected = NEXT_AFTER_TWOCOL[nextExpected] ?? null;
      }
      continue;
    }

    // Try two-column: find all "X) " occurrences on this line
    const twoCol = splitTwoColumnLine(stripped);
    if (twoCol) {
      const leftKey = Object.keys(twoCol)[0];
      for (const [k, v] of Object.entries(twoCol)) { choices[k] = v; current = k; }
      nextExpected = NEXT_AFTER_TWOCOL[leftKey] ?? null;
      continue;
    }

    // Single choice — allow zero or more spaces after ) ("A) -4" or "A)-4")
    const single = stripped.match(/^\*{0,2}([A-E])\)\*{0,2}\s*(.*)/);
    if (single) {
      current = single[1];
      choices[current] = single[2].trim();
      nextExpected = null;
      continue;
    }

    // Unlabeled content: assign to nextExpected (e.g. B after A+D row) or append to current
    if (nextExpected && !choices[nextExpected]) {
      const val = stripped.startsWith('\\') ? '$' + stripped + '$' : stripped;
      choices[nextExpected] = val;
      current = nextExpected;
      nextExpected = NEXT_AFTER_TWOCOL[nextExpected] ?? null;
    } else if (current) {
      choices[current] += (choices[current] ? ' ' : '') + stripped;
    }
  }

  for (const k of Object.keys(choices)) {
    choices[k] = normalizeChoiceText(choices[k].trim());
  }
  return choices;
}

// Split "A) text1 D) text2" or "A)-4 D)-1" into {A: text1, D: text2}
function splitTwoColumnLine(line) {
  const positions = [];
  const re = /\b([A-E])\)\s*/g;
  let m;
  while ((m = re.exec(line)) !== null) positions.push({ letter: m[1], start: m.index, end: m.index + m[0].length });
  if (positions.length < 2) return null;

  const result = {};
  for (let i = 0; i < positions.length; i++) {
    const from = positions[i].end;
    const to   = i + 1 < positions.length ? positions[i + 1].start : line.length;
    result[positions[i].letter] = line.slice(from, to).trim();
  }
  return result;
}

// Normalize: fix Roman numeral pipes/digits ($| < || < |||$ or $1 < 11 < 111$ → I < II < III)
// MinerU sometimes OCRs Roman numeral I as pipe (|) and sometimes as digit (1)
function normalizeChoiceText(text) {
  // Match LaTeX containing only |, 1, <, >, spaces, commas
  if (/^\$[\s|1<>,]+\$$/.test(text)) {
    return text
      .replace(/^\$|\$$/g, '')           // strip $ delimiters
      // pipe-based: ||| → III, || → II, | → I (longest first)
      .replace(/\|\s*\|\s*\|/g, 'III')
      .replace(/\|\s*\|/g, 'II')
      .replace(/\|/g, 'I')
      // digit-based: 1 1 1 → III, 1 1 → II, lone 1 → I
      .replace(/1\s*1\s*1/g, 'III')
      .replace(/1\s*1/g, 'II')
      .replace(/(?<![A-Z])1(?![A-Z0-9])/g, 'I')  // lone 1 not adjacent to I/digit
      .trim();
  }
  return text;
}

function escRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`PreUni composer → http://localhost:${PORT}/question-composer-prototype.html  [${API_KEY ? 'MinerU Standard' : 'MinerU Agent'}]`));
