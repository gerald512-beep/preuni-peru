// Bulk solucionario parser — Stage 1: structural parsing + validation only.
// Reads a MinerU-processed markdown file, segments it into materia/solution-group
// blocks, splits each into individual questions/solutions, matches them by number,
// and flags anything that needs manual review. Writes bulk_review.json + prints a
// console summary. Does NOT touch Discourse, does NOT resolve figures to base64,
// does NOT call Claude — that's Stage 2, after the parsing structure is confirmed.
//
// Usage: node bulk_seed.js <markdown_file_path> <universidad> <anio> <convocatoria>

const fs = require('fs');
const path = require('path');
const { findFirstChoice, parseChoices } = require('./parse-helpers');

// ── Config: which materias exist, which prueba they belong to, their tema
//    (null = ambiguous, needs Claude in Stage 2), and which solution-group
//    (answer source) they draw from. ──────────────────────────────────────
const MATERIAS = [
  { prueba: 1, header: 'RAZONAMIENTO MATEMÁTICO',        tema: 'Razonamiento Matemático', solutionGroup: '4.1' },
  { prueba: 1, header: 'RAZONAMIENTO VERBAL',             tema: 'Razonamiento Verbal',     solutionGroup: '4.2' },
  { prueba: 1, header: 'COMUNICACIÓN Y LENGUA',           tema: 'Comunicación y Lengua',   solutionGroup: '4.3' },
  { prueba: 1, header: 'LITERATURA',                      tema: 'Literatura',              solutionGroup: '4.3' },
  { prueba: 1, header: 'HISTORIA DEL PERÚ Y DEL MUNDO',   tema: 'Historia del Perú',       solutionGroup: '4.3' },
  { prueba: 1, header: 'GEOGRAFÍA Y DESARROLLO NACIONAL', tema: 'Geografía del Perú',      solutionGroup: '4.3' },
  { prueba: 1, header: 'ECONOMÍA',                        tema: 'Economía',                solutionGroup: '4.3' },
  { prueba: 1, header: 'INGLÉS',                          tema: 'Inglés',                  solutionGroup: '4.3' },
  { prueba: 1, header: 'FILOSOFÍA',                        tema: 'Filosofía',              solutionGroup: '4.3' },
  { prueba: 1, header: 'LÓGICA',                          tema: 'Lógica',                  solutionGroup: '4.3' },
  { prueba: 1, header: 'PSICOLOGÍA',                      tema: 'Psicología',              solutionGroup: '4.3' },
  { prueba: 1, header: 'ACTUALIDAD',                      tema: 'Actualidad',              solutionGroup: '4.3' },
  { prueba: 2, header: 'MATEMÁTICA', tema: null, claudeTemas: ['Aritmética','Álgebra','Geometría','Trigonometría'], solutionGroup: '5.1' },
  { prueba: 3, header: 'FÍSICA',  tema: 'Física',  solutionGroup: '6.1' },
  { prueba: 3, header: 'QUÍMICA', tema: 'Química', solutionGroup: '6.2' },
  { prueba: 'traslado', header: 'MATEMÁTICA BÁSICA I',  tema: null, claudeTemas: ['Aritmética','Álgebra','Geometría','Trigonometría'], solutionGroup: 'traslado' },
  { prueba: 'traslado', header: 'MATEMÁTICA BÁSICA II', tema: null, claudeTemas: ['Aritmética','Álgebra','Geometría','Trigonometría'], solutionGroup: 'traslado' },
  { prueba: 'traslado', header: 'CÁLCULO DIFERENCIAL', tema: 'Cálculo Diferencial', solutionGroup: 'traslado' },
  { prueba: 'traslado', header: 'CÁLCULO INTEGRAL',    tema: 'Cálculo Integral',    solutionGroup: 'traslado' },
];

const SOLUTION_GROUP_FORMAT = {
  '4.1': 'worked', '4.2': 'table', '4.3': 'table',
  '5.1': 'worked', '6.1': 'worked', '6.2': 'worked',
  'traslado': 'table',
};

const HEADER_BY_TEXT = new Map(MATERIAS.map(m => [m.header, m]));

// ── Line normalization: strip leading markdown #'s so "## 53. TITLE" and
//    "53. TITLE" are treated identically (MinerU renders some question/solution
//    openers as headers depending on the original PDF's bold/title styling). ──
function stripHeaderHash(line) {
  return line.replace(/^#{1,4}\s*/, '');
}

// ── Unwrap choices MinerU rendered as a single-line LaTeX array instead of
//    plain "A) text" lines — common for ordering/Plan de Redacción questions:
//    \begin{array}{l l} \text{A) foo} & \text{D) bar} \\ \text{B) baz} ... \end{array}
//    Rewrites matches into normal "A) foo\nD) bar\n..." lines so the standard
//    findFirstChoice/parseChoices pipeline can handle them unmodified. ────────
function unwrapLatexArrayChoices(text) {
  const re = /\\text\s*\{\s*([A-E])\)\s*([^}]*)\}/g;
  const found = [...text.matchAll(re)];
  if (found.length < 2) return text; // not this pattern — leave text untouched

  const arrayBlockRe = /\$\$\s*\\begin\{array\}[\s\S]*?\\end\{array\}\s*\$\$/;
  const block = text.match(arrayBlockRe);
  if (!block) return text;

  const normalized = found.map(m => `${m[1]}) ${m[2].trim()}`).join('\n');
  return text.replace(arrayBlockRe, '\n' + normalized + '\n');
}

// ── MinerU sometimes runs the last Roman-numeral proposition (I./II./III.)
//    directly into the first choice pair on the same physical line:
//    "...III. (r ∨ ∼p) A) Solo I    D) I y II" — so "A)" isn't at true
//    line-start and findFirstChoice misses it, losing A and D into the body.
//    Insert a line break before "A)" only when real content precedes it AND
//    a "D)" also appears later on that same line (confirms a genuine pair,
//    avoids splitting an already-clean "A) ... D) ..." line at position 0). ──
function fixInlineChoiceStart(text) {
  return text.replace(/^(.*\S)\s+(A\)\s*.*?\s+D\).*)$/gm, (_, prefix, rest) => `${prefix}\n${rest}`);
}

// ── Phase 1: linear scan — tag every line as a boundary marker or content ──
function segmentDocument(text) {
  const lines = text.split('\n');
  const blocks = []; // { kind: 'materia'|'solutionGroup', materia?, group?, lines: [] }
  let current = null;

  const SOLUTION_GROUP_HEADER_RE = /^(\d\.\d)\.\s*.*/;
  const TRASLADO_MARKER = 'Solución de la Prueba de Matemática Traslado Externo';

  for (const rawLine of lines) {
    const stripped = stripHeaderHash(rawLine.trim());

    // Solution-group boundary: "4.1. Raz. Matemático" style, or the Traslado marker
    const groupMatch = stripped.match(SOLUTION_GROUP_HEADER_RE);
    if (groupMatch && SOLUTION_GROUP_FORMAT[groupMatch[1]]) {
      if (current) blocks.push(current);
      current = { kind: 'solutionGroup', group: groupMatch[1], lines: [] };
      continue;
    }
    if (stripped.startsWith(TRASLADO_MARKER)) {
      if (current) blocks.push(current);
      current = { kind: 'solutionGroup', group: 'traslado', lines: [] };
      continue;
    }

    // Materia boundary: exact whole-line match against known headers
    const materia = HEADER_BY_TEXT.get(stripped);
    if (materia) {
      if (current) blocks.push(current);
      current = { kind: 'materia', materia, lines: [] };
      continue;
    }

    if (current) current.lines.push(rawLine);
  }
  if (current) blocks.push(current);
  return blocks;
}

// ── Split a block's raw text into numbered items (questions or worked solutions).
//    Requires strictly increasing numbers to reject false-positive digit matches
//    inside LaTeX/body text. Returns [{ num, text }]. ─────────────────────────
function splitByNumberedBoundary(lines) {
  const items = [];
  let current = null;
  let lastNum = 0;

  for (const rawLine of lines) {
    const stripped = stripHeaderHash(rawLine.trim());
    const m = stripped.match(/^(\d{1,3})\.\s+(\S.*)/);
    if (m) {
      const num = parseInt(m[1], 10);
      if (num > lastNum) {
        if (current) items.push(current);
        current = { num, lines: [m[2]] };
        lastNum = num;
        continue;
      }
    }
    if (current) current.lines.push(rawLine);
  }
  if (current) items.push(current);
  return items.map(it => ({ num: it.num, text: it.lines.join('\n').trim() }));
}

// ── Parse a table-format solution block: <table>...<td>N</td><td>X</td>... ──
function parseAnswerTable(text) {
  const map = {};
  const re = /<td>\s*(\d{1,3})\s*<\/td>\s*<td>\s*([A-E])\s*<\/td>/g;
  let m;
  while ((m = re.exec(text)) !== null) map[parseInt(m[1], 10)] = m[2];
  return map;
}

// ── OA extraction from a worked-solution block: letter-direct, then value-fallback
//    against the matched question's own parsed choices. Never guesses. ────────
function normalizeForMatch(s) {
  return (s || '')
    .replace(/\$/g, '')
    .replace(/\\[a-zA-Z]+/g, '')   // strip LaTeX commands (\frac, \sqrt, etc.)
    .replace(/[{}\\]/g, '')
    .replace(/\s+/g, '')
    .toLowerCase();
}

function extractOA(solutionText, questionChoices) {
  const letterMatch = solutionText.match(/Respuesta\s*[:]?\s*([A-E])\b/i);
  if (letterMatch) return { clave: letterMatch[1].toUpperCase(), method: 'letter' };

  const valueMatch = solutionText.match(/Respuesta\s*[:]?\s*(.+?)\s*$/im);
  if (valueMatch && questionChoices) {
    const target = normalizeForMatch(valueMatch[1]);
    if (target) {
      const hits = ['A','B','C','D','E'].filter(l => normalizeForMatch(questionChoices[l]) === target);
      if (hits.length === 1) return { clave: hits[0], method: 'value_fallback' };
    }
  }
  return { clave: null, method: null };
}

// ── Choice validation: exactly 5 non-empty A–E slots (text OR a resolved image) ──
function validateChoices(choices, choiceImages) {
  return ['A','B','C','D','E'].filter(l => !choices[l]?.trim() && !choiceImages?.[l]);
}

// ── Split a parsed choice set: a choice that's just a markdown image ref
//    ("![](images/xxx.jpg)") becomes an empty text choice + a resolved
//    data-URL image, matching the shape the composer already expects for
//    per-choice images (choices_are_images / choiceImages map). ───────────
const CHOICE_IMAGE_RE = /^!\[.*?\]\((images\/[^)]+)\)$/;

function splitChoiceImages(choices, imagesDir) {
  const cleanChoices = {}, choiceImages = {};
  for (const l of ['A','B','C','D','E']) {
    const val = (choices[l] || '').trim();
    const m = val.match(CHOICE_IMAGE_RE);
    const dataUrl = m ? resolveFigureToDataUrl(m[1], imagesDir) : null;
    if (dataUrl) { choiceImages[l] = dataUrl; cleanChoices[l] = ''; }
    else { cleanChoices[l] = choices[l] || ''; }
  }
  return { cleanChoices, choiceImages };
}

// ── Main ─────────────────────────────────────────────────────────────────
function main() {
  const [,, mdPath, universidad, anio, convocatoria] = process.argv;
  if (!mdPath || !universidad || !anio) {
    console.error('Usage: node bulk_seed.js <markdown_file> <universidad> <anio> [convocatoria]');
    process.exit(1);
  }

  const imagesDir = path.join(path.dirname(mdPath), 'images');
  const text = fs.readFileSync(mdPath, 'utf8');
  const blocks = segmentDocument(text);

  // Collect raw materia question-blocks and raw solution-group blocks
  const materiaBlocks = blocks.filter(b => b.kind === 'materia');
  const groupBlocks = blocks.filter(b => b.kind === 'solutionGroup');

  // Parse questions per materia occurrence (a materia header can legitimately
  // repeat, e.g. none here, but keep it general)
  const questionsByMateria = []; // [{ materia, items: [{num, body, choices}] }]
  for (const b of materiaBlocks) {
    const items = splitByNumberedBoundary(b.lines)
      .map(it => ({ ...it, text: fixInlineChoiceStart(unwrapLatexArrayChoices(it.text)) }))
      .map(it => {
        const firstChoice = findFirstChoice(it.text);
        const rawBody = firstChoice > 0 ? it.text.slice(0, firstChoice).trim() : (firstChoice < 0 ? it.text : '');
        const choiceRaw = firstChoice >= 0 ? it.text.slice(firstChoice) : '';
        const choices = parseChoices(choiceRaw);
        const { markedText: body, refs: rawFigureRefs } = insertFigureMarkers(rawBody);
        return { num: it.num, body, choices, rawFigureRefs };
      });
    if (items.length > 0) questionsByMateria.push({ materia: b.materia, items });
  }

  // Parse solution groups: table format → {num:clave}; worked → {num: {clave, method, body}}
  const solutionsByGroup = {}; // group -> { format, table?: {}, worked?: {num: {...}} }
  for (const b of groupBlocks) {
    const format = SOLUTION_GROUP_FORMAT[b.group];
    const groupText = b.lines.join('\n');
    if (format === 'table') {
      const existing = solutionsByGroup[b.group]?.table || {};
      solutionsByGroup[b.group] = { format, table: { ...existing, ...parseAnswerTable(groupText) } };
    } else {
      const items = splitByNumberedBoundary(b.lines);
      const worked = solutionsByGroup[b.group]?.worked || {};
      for (const it of items) {
        const { markedText, refs } = insertFigureMarkers(it.text);
        worked[it.num] = { text: markedText, rawFigureRefs: refs };
      }
      solutionsByGroup[b.group] = { format, worked };
    }
  }

  // Assemble final question records
  const results = [];
  const gapsByMateria = {};

  for (const { materia, items } of questionsByMateria) {
    // detect numbering gaps
    const nums = items.map(i => i.num).sort((a, b) => a - b);
    const missingNums = [];
    for (let n = nums[0]; n <= nums[nums.length - 1]; n++) {
      if (!nums.includes(n)) missingNums.push(n);
    }
    if (missingNums.length) gapsByMateria[materia.header] = missingNums;

    const group = solutionsByGroup[materia.solutionGroup];

    for (const q of items) {
      const needsReview = [];

      // A choice that's just a markdown image ref ("A) [image]") is a real,
      // valid choice — split it out so validation and the composer both see
      // it as present, instead of raw "![](images/...)" text or a false miss.
      const { cleanChoices, choiceImages } = splitChoiceImages(q.choices, imagesDir);
      const missingChoices = validateChoices(cleanChoices, choiceImages);
      if (missingChoices.length) needsReview.push(`missing_choices:${missingChoices.join(',')}`);

      let clave = null, oaMethod = null, solutionBody = null, solutionFigureRefs = [];
      if (!group) {
        needsReview.push('no_solution_group_found');
      } else if (group.format === 'table') {
        clave = group.table[q.num] || null;
        oaMethod = clave ? 'table' : null;
        if (!clave) needsReview.push('oa_not_found_in_table');
      } else {
        const sol = group.worked[q.num];
        if (!sol) {
          needsReview.push('worked_solution_not_found');
        } else {
          const oa = extractOA(sol.text, q.choices);
          clave = oa.clave;
          oaMethod = oa.method;
          solutionBody = sol.text;
          solutionFigureRefs = sol.rawFigureRefs;
          if (!clave) needsReview.push('oa_unmatched');
          else if (oa.method === 'value_fallback') needsReview.push('oa_value_fallback_used');
        }
      }

      const figureImages = q.rawFigureRefs.map(ref => resolveFigureToDataUrl(ref, imagesDir)).filter(Boolean);
      const solutionFigureImages = solutionFigureRefs.map(ref => resolveFigureToDataUrl(ref, imagesDir)).filter(Boolean);

      results.push({
        id: `p${materia.prueba}-${materia.header.replace(/\s+/g, '_')}-${String(q.num).padStart(2, '0')}`,
        prueba: materia.prueba,
        materiaHeader: materia.header,
        numero: q.num,
        tema: materia.tema,
        pendingClassification: materia.tema === null,
        claudeTemas: materia.claudeTemas || null,
        body: q.body,
        choices: cleanChoices,
        choiceImages,
        figureRefs: q.rawFigureRefs,
        figureImages,
        clave,
        oaMethod,
        solutionBody,
        solutionFigureRefs,
        solutionFigureImages,
        universidad, anio, convocatoria: convocatoria || '',
        needsReview,
      });
    }
  }

  // ── Output ──────────────────────────────────────────────────────────────
  const outPath = path.join(__dirname, 'bulk_review.json');
  fs.writeFileSync(outPath, JSON.stringify(results, null, 2));

  const clean = results.filter(r => r.needsReview.length === 0);
  const flagged = results.filter(r => r.needsReview.length > 0);

  console.log(`\nParsed ${results.length} questions across ${questionsByMateria.length} materia sections.`);
  console.log(`Clean: ${clean.length}   Flagged for review: ${flagged.length}\n`);

  console.log('By materia:');
  for (const { materia, items } of questionsByMateria) {
    const flaggedInMateria = items.filter(q => {
      const r = results.find(x => x.materiaHeader === materia.header && x.numero === q.num);
      return r?.needsReview.length > 0;
    }).length;
    console.log(`  ${materia.header.padEnd(30)} prueba=${String(materia.prueba).padEnd(9)} n=${String(items.length).padStart(3)}  flagged=${flaggedInMateria}${materia.tema === null ? '  [needs Claude classification]' : ''}`);
  }

  if (Object.keys(gapsByMateria).length) {
    console.log('\nNumbering gaps (questions MinerU likely failed to extract):');
    for (const [materiaName, gaps] of Object.entries(gapsByMateria)) {
      console.log(`  ${materiaName}: missing #${gaps.join(', #')}`);
    }
  }

  if (flagged.length) {
    console.log('\nFlagged questions (reason):');
    for (const r of flagged) {
      console.log(`  ${r.id}  [${r.needsReview.join(', ')}]`);
    }
  }

  console.log(`\nWrote ${outPath}`);
}

function extractRawImageRefs(text) {
  const refs = [];
  const re = /!\[.*?\]\((images\/[^)]+)\)/g;
  let m;
  while ((m = re.exec(text)) !== null) refs.push(m[1]);
  return refs;
}

// Replace inline "![](images/xxx.jpg)" markdown with [FIG:N] markers so the
// image's position in the text is preserved — matches what the composer's
// own parseResult() does for single-question extraction. Without this, an
// inline figure shows as raw unrendered markdown mid-sentence, and the
// resolved image ends up disconnected in a gallery instead of in place.
// /api/publish also requires [FIG:N] markers to know where to insert the
// uploaded Discourse image URL — without them a bulk-published figure would
// either vanish or leave a broken local file path in the final post.
function insertFigureMarkers(text) {
  const refs = [];
  const markedText = text.replace(/!\[.*?\]\((images\/[^)]+)\)/g, (_, ref) => {
    const idx = refs.length;
    refs.push(ref);
    return `[FIG:${idx}]`;
  });
  return { markedText, refs };
}

const MIME_BY_EXT = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png' };

function resolveFigureToDataUrl(ref, imagesDir) {
  const filePath = path.join(imagesDir, path.basename(ref));
  if (!fs.existsSync(filePath)) return null;
  const ext = path.extname(filePath).toLowerCase();
  const mime = MIME_BY_EXT[ext] || 'image/jpeg';
  const buf = fs.readFileSync(filePath);
  return `data:${mime};base64,${buf.toString('base64')}`;
}

main();
