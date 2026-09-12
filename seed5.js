require('dotenv').config();
const fetch = globalThis.fetch || require('node-fetch');

const DISCOURSE_URL = process.env.DISCOURSE_URL || 'http://localhost:8080';
const API_KEY       = process.env.DISCOURSE_API_KEY;
const API_USER      = process.env.DISCOURSE_API_USERNAME || 'gerald';

const CATEGORY_MAP = {
  UNI: {
    'Aritmética': 16, 'Álgebra': 17, 'Geometría': 18, 'Trigonometría': 19,
    'Física': 20, 'Química': 21, 'Razonamiento Matemático': 22,
    'Razonamiento Verbal': 23, 'Historia del Perú': 24,
    'Geografía del Perú': 25, 'Literatura': 26, 'Filosofía': 27,
  },
  UNMSM: {
    'Aritmética': 7, 'Álgebra': 8, 'Geometría': 9, 'Trigonometría': 10,
    'Razonamiento Matemático': 11, 'Razonamiento Verbal': 12,
    'Literatura': 13, 'Historia del Perú': 14, 'Geografía del Perú': 15,
  },
};

function buildTitle(body) {
  const clean = body
    .replace(/\$\$[\s\S]*?\$\$/g, '')
    .replace(/\\frac\{([^}]+)\}\{([^}]+)\}/g, '$1/$2')
    .replace(/\$([^$]+)\$/g, (_, m) => m.replace(/\\_/g, '_').replace(/\{|\}/g, ''))
    .replace(/\[FIG:\d+\]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
  return clean.length > 80 ? clean.slice(0, 80) + '…' : clean;
}

function buildRaw(body, choices) {
  let raw = body.trim() + '\n\n';
  ['A','B','C','D','E'].forEach(l => {
    if (choices[l]) raw += `**(${l})** ${choices[l]}\n`;
  });
  return raw;
}

async function publish(q, idx) {
  const categoryId = CATEGORY_MAP[q.universidad]?.[q.tema];
  if (!categoryId) throw new Error(`No category for ${q.universidad}/${q.tema}`);

  const numero = q.numero || q._num;
  const title  = buildTitle(q.body);
  const raw    = buildRaw(q.body, q.choices);

  const headers = {
    'Content-Type': 'application/json',
    'Api-Key': API_KEY,
    'Api-Username': API_USER,
  };

  // Create topic with custom fields in a single POST
  // topic_custom_fields must go in the initial create_params call (POST /posts.json)
  // PUT /posts/:id update action does NOT process topic_custom_fields
  const postRes = await fetch(`${DISCOURSE_URL}/posts.json`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      title,
      raw,
      category: categoryId,
      tags: [`N°${numero}`],
      topic_custom_fields: {
        preuni_clave:        q.oa,
        preuni_convocatoria: q.convocatoria || '',
        preuni_numero:       String(numero || ''),
        preuni_universidad:  q.universidad,
        preuni_tema:         q.tema,
        preuni_tipo_origen:  'Universidad',
      },
    }),
  });
  if (!postRes.ok) {
    const err = await postRes.json().catch(() => ({}));
    throw new Error(err.errors?.join(', ') || `HTTP ${postRes.status}`);
  }
  const post = await postRes.json();
  const topicId = post.topic_id;

  return `${DISCOURSE_URL}/t/${post.topic_slug}/${topicId}`;
}

async function main() {
  const all = require('./pdfs/solucionario2011_questions.json');
  const ready = all.filter(q => !q.has_figure && CATEGORY_MAP[q.universidad]?.[q.tema]);
  // Q6, Q20-Q23 already published as topics 35-39
  const ALREADY_PUBLISHED = new Set([6, 20, 21, 22, 23]);
  const batch = ready.filter(q => !ALREADY_PUBLISHED.has(q._num));

  console.log(`Publishing ${batch.length} questions...\n`);
  for (let i = 0; i < batch.length; i++) {
    const q = batch[i];
    try {
      const url = await publish(q, i);
      console.log(`[${i+1}/${batch.length}] Q${q._num} ${q.tema} → ${url}`);
    } catch (e) {
      console.error(`[${i+1}/${batch.length}] Q${q._num} FAILED: ${e.message}`);
    }
    if (i < batch.length - 1) await new Promise(r => setTimeout(r, 1500));
  }
}

main();
