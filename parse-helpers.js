// Shared choice-parsing logic used by both the single-question composer (server.js)
// and the bulk seeding pipeline (bulk_seed.js). Keeping this in one module means
// both paths interpret MinerU's messy two-column / LaTeX-choice output identically.

function findFirstChoice(text) {
  // Allow zero spaces after ) — MinerU sometimes outputs "A)-4" without space
  const m = /(?:^|\n)\s*([A-E])\)/m.exec(text);
  if (!m) return -1;
  return m.index + (m[0].startsWith('\n') ? 1 : 0);
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
    // Don't reset `current` on a blank line — MinerU often puts a blank line
    // between a choice label ("A)") and its image, on its own line below it.
    if (!stripped) continue;

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

module.exports = { findFirstChoice, parseChoices, splitTwoColumnLine, normalizeChoiceText, escRe };
