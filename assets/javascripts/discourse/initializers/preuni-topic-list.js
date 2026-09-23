import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

const CSS = `
.preuni-filter-bar{
  display:flex;align-items:center;gap:6px;padding:8px 0 12px;flex-wrap:wrap
}
.preuni-filter-label{font-size:12px;color:#888;font-weight:600;margin-right:2px}
.preuni-filter-btn{
  padding:3px 12px;border-radius:20px;border:1.5px solid #cdd;
  background:#f8f8f8;font-size:12px;cursor:pointer;color:#555;
  transition:all .15s;font-weight:500;line-height:1.6
}
.preuni-filter-btn:hover{border-color:#999}
.preuni-filter-btn.active[data-filter="todos"]     {background:#00529b;border-color:#00529b;color:#fff;font-weight:700}
.preuni-filter-btn.active[data-filter="facil"]     {background:#d4edda;border-color:#28a745;color:#155724;font-weight:700}
.preuni-filter-btn.active[data-filter="medio"]     {background:#fff3cd;border-color:#ffc107;color:#856404;font-weight:700}
.preuni-filter-btn.active[data-filter="dificil"]   {background:#f8d7da;border-color:#dc3545;color:#721c24;font-weight:700}
.preuni-filter-btn.active[data-filter="por_definir"]{background:#e9ecef;border-color:#adb5bd;color:#495057;font-weight:700}
`;

const DIF_MAP = {
  facil:       { bg: '#d4edda', color: '#155724', border: '#c3e6cb', label: 'Fácil'       },
  medio:       { bg: '#fff3cd', color: '#856404', border: '#ffeeba', label: 'Medio'       },
  dificil:     { bg: '#f8d7da', color: '#721c24', border: '#f5c6cb', label: 'Difícil'     },
  por_definir: { bg: '#e9ecef', color: '#6c757d', border: '#dee2e6', label: 'Por definir' },
  // A reading-passage cluster topic has several independently-scored
  // questions -- one facil/medio/dificil value would misrepresent the whole
  // topic, so this gets its own badge instead. Not included in FILTER_BUTTONS
  // since "difficulty" isn't a meaningful axis to filter these by.
  lectura:     { bg: '#e4e8f2', color: '#2b3f6b', border: '#c8d2e8', label: 'Lectura'      },
};

const FILTER_BUTTONS = [
  { key: 'todos',      label: 'Todos'       },
  { key: 'facil',      label: 'Fácil'       },
  { key: 'medio',      label: 'Medio'       },
  { key: 'dificil',    label: 'Difícil'     },
  { key: 'por_definir',label: 'Por definir' },
];

let cache = {};
let cacheLoaded = false;
let activeFilter = 'todos';

async function ensureCache() {
  if (cacheLoaded) return;
  try {
    const data = await ajax('/preuni/difficulties');
    const raw = data.difficulties || {};
    cache = {};
    Object.entries(raw).forEach(([k, v]) => { cache[parseInt(k)] = v; });
  } catch (_) {
    cache = {};
  }
  cacheLoaded = true;
}

function getTopicIdFromRow(row) {
  if (row.dataset.topicId) return parseInt(row.dataset.topicId);
  const link = row.querySelector('a[data-topic-id]');
  if (link) return parseInt(link.dataset.topicId);
  const href = row.querySelector('a.title, a.raw-link')?.getAttribute('href') || '';
  const m = href.match(/\/t\/[^/]+\/(\d+)/);
  return m ? parseInt(m[1]) : null;
}

function addChipsToRows() {
  document.querySelectorAll('.topic-list-item').forEach(row => {
    row.querySelector('.preuni-list-chip')?.remove();

    const topicId = getTopicIdFromRow(row);
    if (!topicId) return;

    const info = cache[topicId];
    if (!info) return;

    const c = DIF_MAP[info.dificultad];
    if (!c) return;

    const chip = document.createElement('span');
    chip.className = 'preuni-list-chip';
    chip.dataset.dif = info.dificultad;
    chip.style.cssText = `display:inline-flex;align-items:center;padding:1px 7px;border-radius:4px;font-size:11px;font-weight:600;background:${c.bg};color:${c.color};border:1px solid ${c.border};margin-left:6px;vertical-align:middle;white-space:nowrap`;
    chip.textContent = info.dificultad === 'lectura' ? `${c.label} · ${info.num_preguntas} preg.` : c.label;

    const title = row.querySelector('a.title');
    if (title) title.after(chip);
  });
}

function injectFilterBar() {
  if (document.getElementById('preuni-filter-bar')) return;

  const list = document.querySelector('.topic-list');
  if (!list) return;

  // Only show bar if this page has at least one preuni topic
  const hasPreuni = Array.from(document.querySelectorAll('.topic-list-item'))
    .some(row => { const id = getTopicIdFromRow(row); return id && cache[id]; });
  if (!hasPreuni) return;

  const bar = document.createElement('div');
  bar.id = 'preuni-filter-bar';
  bar.innerHTML =
    `<span class="preuni-filter-label">Dificultad:</span>` +
    FILTER_BUTTONS.map(b =>
      `<button class="preuni-filter-btn${b.key === activeFilter ? ' active' : ''}" data-filter="${b.key}">${b.label}</button>`
    ).join('');

  list.parentElement.insertBefore(bar, list);

  bar.querySelectorAll('.preuni-filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      activeFilter = btn.dataset.filter;
      bar.querySelectorAll('.preuni-filter-btn').forEach(b =>
        b.classList.toggle('active', b.dataset.filter === activeFilter)
      );
      applyFilter();
    });
  });
}

function applyFilter() {
  document.querySelectorAll('.topic-list-item').forEach(row => {
    if (activeFilter === 'todos') { row.style.display = ''; return; }

    // Always keep pinned topics visible
    if (row.classList.contains('pinned')) { row.style.display = ''; return; }

    const topicId = getTopicIdFromRow(row);
    const info = topicId ? cache[topicId] : null;
    row.style.display = (info && info.dificultad === activeFilter) ? '' : 'none';
  });
}

function tryInject(attempt = 0) {
  const list = document.querySelector('.topic-list');
  if (!list && attempt < 6) { setTimeout(() => tryInject(attempt + 1), 150); return; }
  addChipsToRows();
  injectFilterBar();
  applyFilter();
}

export default {
  name: "preuni-topic-list",
  initialize() {
    if (!document.getElementById("preuni-topic-list-css")) {
      const s = document.createElement("style");
      s.id = "preuni-topic-list-css";
      s.textContent = CSS;
      document.head.appendChild(s);
    }

    withPluginApi("1.0", (api) => {
      // Discourse sends a partly-read topic's title link to its first UNREAD
      // post. In a question topic that is the solution reply, so the link
      // landed mid-thread on the answer. Question topics (they live in the
      // university subcategories) always open at the top, on the question.
      // Ordinary discussion threads keep the default resume behavior.
      api.registerCustomLastUnreadUrlCallback((topic) =>
        topic.category?.parentCategory ? topic.urlForPostNumber(1) : null
      );

      // Personal error log page (/errores); only signed-in students have one.
      if (api.getCurrentUser()) {
        api.addCommunitySectionLink({
          name: "preuni-errores",
          route: "preuni-errores",
          title: "Tus respuestas incorrectas, notas y precisión",
          text: "Registro de errores",
          icon: "clipboard-list",
        });
      }

      api.onPageChange(async (url) => {
        activeFilter = 'todos';
        document.getElementById('preuni-filter-bar')?.remove();

        // Only activate on listing pages, not topic detail pages
        if (!url.includes('/c/') && !url.match(/^\/(latest|top|new)(\/|$)/)) return;

        await ensureCache();
        tryInject();
      });
    });
  },
};
