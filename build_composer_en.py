"""Build composer_en.html (public English demo, served at /composer_en) from
question-composer-prototype.html. Rerun after changing the Spanish composer:
    python build_composer_en.py

The demo differs from the admin composer in four ways:
  * every visible text is in English (taxonomy values stay Spanish, only their
    display labels are translated, so extraction results still match);
  * extraction is asynchronous (start a job, poll it) through /composer_en/api;
  * no Discourse access: no duplicate check, no linked-question mode;
  * the submit button is "Preview": it never publishes -- it opens the preview as an overlay.
Every replacement asserts how many times it matched, so a change in the source
fails loudly instead of leaving Spanish text behind.
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, 'question-composer-prototype.html')
DST = os.path.join(ROOT, 'composer_en.html')

s = io.open(SRC, encoding='utf-8', newline='').read().replace('\r\n', '\n')


def rep(old, new, count=1):
    global s
    n = s.count(old)
    assert n == count, f'expected {count}x, found {n}x: {old[:70]!r}'
    s = s.replace(old, new)


def cut(start, end, new):
    """Replace s[start:end) (end marker kept) with new."""
    global s
    i, j = s.index(start), s.index(end)
    assert i < j, (start, end)
    s = s[:i] + new + s[j:]


# ── Page chrome ───────────────────────────────────────────────────────────────
rep('<html lang="es">', '<html lang="en">')
rep('<title>PreUni — Nueva Pregunta (Prototipo)</title>', '<title>PreUni — New Question (Demo)</title>')
rep('<h1>PreUni Peru — Nueva Pregunta</h1>', '<h1>PreUni Peru — New Question</h1>')
rep('<span class="badge">ADMIN</span>', '<span class="badge">DEMO</span>')
rep('<span id="ai-status-text">MinerU listo</span>', '<span id="ai-status-text">MinerU ready</span>')
# Linked questions attach to an already-published topic: needs Discourse.
rep('<div class="toggle-sol-wrap">\n    <input type="checkbox" id="chk-linked"',
    '<div class="toggle-sol-wrap" style="display:none">\n    <input type="checkbox" id="chk-linked"')

# ── Image capture ─────────────────────────────────────────────────────────────
rep('Capturar imagen de la pregunta <span>— hasta 2 imágenes si la pregunta está en dos columnas</span>',
    'Question image <span>— up to 2 images if the question spans two columns</span>')
rep('Capturar imagen de la solución <span>— hasta 2 imágenes si la solución está en dos páginas</span>',
    'Solution image <span>— up to 2 images if the solution spans two pages</span>')
rep('<div class="zone-label">Imagen 1</div>', '<div class="zone-label">Image 1</div>', 2)
rep('<div class="zone-label">Imagen 2 <em style="font-weight:400">(opcional)</em></div>',
    '<div class="zone-label">Image 2 <em style="font-weight:400">(optional)</em></div>', 2)
rep('<strong>Haz clic y pega (Ctrl+V)</strong>', '<strong>Click, then paste (Ctrl+V)</strong>', 4)
rep('columna siguiente · o arrastra · ', 'next column · or drag · ')
rep('página siguiente · o arrastra · ', 'next page · or drag · ')
rep('o arrastra · <button', 'or drag · <button', 2)
rep('>Elegir archivo</button>', '>Choose file</button>', 4)
rep('>Limpiar</button>', '>Clear</button>', 4)
rep('>Cargar pregunta</button>', '>Extract question</button>')
rep("btn.textContent = 'Cargar pregunta';", "btn.textContent = 'Extract question';")
rep('>Cargar solución</button>', '>Extract solution</button>')
rep("btn.textContent = 'Cargar solución';", "btn.textContent = 'Extract solution';")
rep("avisar('Haz clic en el recuadro donde quieres pegar la imagen y vuelve a pegar.');",
    "avisar('Click the box where you want to paste the image, then paste again.');")

# ── Form ──────────────────────────────────────────────────────────────────────
rep('<h2>Completa o edita manualmente</h2>', '<h2>Complete or edit manually</h2>', 2)
rep('Enunciado <span>— acepta LaTeX con $ ... $ o $$ ... $$</span>',
    'Question text <span>— supports LaTeX with $ ... $ or $$ ... $$</span>')
rep('placeholder="Ej: Si $x^2 - 5x + 6 = 0$, ¿cuál es la suma de sus raíces?"',
    'placeholder="e.g. If $x^2 - 5x + 6 = 0$, what is the sum of its roots?"')
rep('<label>Alternativas</label>', '<label>Answer choices</label>')
rep('Escribe texto o LaTeX en cada alternativa. Para adjuntar una imagen, usa <strong>&#9986; Insertar imagen</strong> — la imagen reemplazará el texto en la vista previa.',
    'Type text or LaTeX in each choice. To attach an image, use <strong>&#9986; Insert image</strong> — the image replaces the text in the preview.')
for l in 'ABCDE':
    rep(f'placeholder="Alternativa {l} — texto o LaTeX"', f'placeholder="Choice {l} — text or LaTeX"')
rep('>&#9986; Insertar imagen</button>', '>&#9986; Insert image</button>', 5)
rep('>&#10005; Quitar imagen</button>', '>&#10005; Remove image</button>', 5)
rep('<label>Clave</label>', '<label>Answer key</label>')
rep('<label>Universidad</label>', '<label>University</label>')
rep('<option value="">— seleccionar —</option>', '<option value="">— select —</option>', 3)
rep('<label>Año</label>', '<label>Year</label>')
rep('<label>Conv.</label>', '<label>Round</label>')
rep('<label>N°</label>', '<label>No.</label>', 2)
rep('Modalidad <span>— opcional</span>', 'Admission type <span>— optional</span>')
rep('<option value="Ordinario">Ordinario</option>', '<option value="Ordinario">Regular</option>')
rep('<option value="Traslado">Traslado</option>', '<option value="Traslado">Transfer</option>')
rep('<option value="Escolar">Escolar</option>', '<option value="Escolar">School</option>')
rep('<option value="Simulacro">Simulacro</option>', '<option value="Simulacro">Practice exam</option>')
rep('Tipo / Área <span>— opcional</span>', 'Exam / Area <span>— optional</span>')
rep('— selecciona universidad primero —', '— select a university first —', 2)
rep('<label>Tema</label>', '<label>Subject</label>')
rep('Sub-tema <span>— Ctrl+click para seleccionar varios</span>', 'Topic <span>— Ctrl+click to select several</span>')
rep('Selecciona todas las técnicas que aplican, aunque sean de distintos temas.',
    'Select every technique that applies, even across subjects.')
rep('<label for="chk-solucion">Agregar solución</label>', '<label for="chk-solucion">Add solution</label>')
rep('<h2>Solución</h2>', '<h2>Solution</h2>')
rep('Texto de la solución <span>— acepta LaTeX con $ ... $ o $$ ... $$</span>',
    'Solution text <span>— supports LaTeX with $ ... $ or $$ ... $$</span>')
rep('placeholder="La solución extraída aparecerá aquí. Edita si es necesario."',
    'placeholder="The extracted solution will appear here. Edit it if needed."')

# ── Validation + submit ───────────────────────────────────────────────────────
rep('⚠ Revisa antes de publicar', '⚠ Check before previewing')
rep('🔴 Errores — necesitas resolverlos', '🔴 Errors — fix these first')
rep('🟡 Advertencias — puedes publicar igualmente', '🟡 Warnings — you can still preview')
rep('>Publicar pregunta</button>', '>Preview</button>')
rep("'Publicar pregunta'", "'Preview'", 4)
rep("'Verificando…'", "'Checking…'")
rep("'⚠ Publicar de todas formas'", "'⚠ Preview anyway'")
rep("'Enunciado: no puede estar vacío'", "'Question text: cannot be empty'")
rep("'Clave: no seleccionada'", "'Answer key: not selected'", 2)
rep('`Alternativas sin contenido: ${', '`Choices without content: ${')
rep("'Universidad: obligatoria'", "'University: required'")
rep("'Año: obligatorio'", "'Year: required'")
rep("'Sub-tema: selecciona al menos uno'", "'Topic: select at least one'")
rep('`Enunciado: [FIG:${mf[0]}] sin imagen asignada`', '`Question text: [FIG:${mf[0]}] has no image assigned`')
rep("'Solución: checkbox marcado pero sin texto ni imagen'", "'Solution: box checked but no text or image'")
rep('`Solución: muy corta (${solBody.length}/20 caracteres mínimo)`', '`Solution: too short (${solBody.length}/20 characters minimum)`')
rep('`Solución: [FIG:${mf[0]}] sin imagen asignada`', '`Solution: [FIG:${mf[0]}] has no image assigned`')
rep("'N° de pregunta no ingresado — la pregunta no tendrá etiqueta con su número'",
    "'Question number missing — the question will not get a number tag'")
rep("'LaTeX posiblemente incompleto: $ sin cerrar en el Enunciado'", "'Possibly incomplete LaTeX: unclosed $ in the question text'")
rep('`LaTeX posiblemente incompleto en Alternativa ${l}`', '`Possibly incomplete LaTeX in choice ${l}`')
# The duplicate check asks Discourse (admin API): not available in the demo.
cut('  // Duplicate check\n', '\n  return { errors, warnings };', '')

# ── Preview panel ─────────────────────────────────────────────────────────────
rep('<h2>Vista previa del tema en Discourse</h2>', '<h2>Question preview</h2>')
rep('Tu pregunta aparecerá aquí', 'Your question will appear here', 2)
rep('El enunciado con LaTeX renderizado aparecerá aquí...', 'The question text with rendered LaTeX will appear here...')
rep('&#9986; Recortar e insertar manualmente', '&#9986; Crop and insert manually')
rep('>Clave: no seleccionada<', '>Answer key: not selected<')
rep('`Clave: ${selectedClave}`', '`Answer key: ${selectedClave}`')
rep('visible solo para admins', 'visible to admins only')
rep('>✓ Solución</span>', '>✓ Solution</span>')
rep('post #2 · preuni_post_type = solucion', 'reply #2 · solution post')
rep('La solución aparecerá aquí...', 'The solution will appear here...', 2)
rep('&#9986; Recortar e insertar en solución', '&#9986; Crop and insert into solution')
rep("'<em style=\"color:#aaa\">El enunciado aparecerá aquí...</em>'", "'<em style=\"color:#aaa\">The question text will appear here...</em>'")
rep('`<em style="color:#ccc">Alternativa ${l}</em>`', '`<em style="color:#ccc">Choice ${l}</em>`')
rep("'<option value=\"\">— seleccionar tema —</option>'", "'<option value=\"\">— select subject —</option>'")

# ── Figures + cropping ────────────────────────────────────────────────────────
rep('alt="Figura ${idx+1}"', 'alt="Figure ${idx+1}"', 3)
rep('alt="Figura sol ${idx+1}"', 'alt="Solution figure ${idx+1}"', s.count('alt="Figura sol ${idx+1}"'))
rep('>&#9986; Recortar</button>', '>&#9986; Crop</button>', s.count('>&#9986; Recortar</button>'))
rep('>&#10005; Eliminar</button>', '>&#10005; Delete</button>', s.count('>&#10005; Eliminar</button>'))
rep('Arrastra para seleccionar el área a recortar', 'Drag to select the area to crop', 2)
rep('>Cancelar</button>', '>Cancel</button>', s.count('>Cancelar</button>'))
rep('>Confirmar recorte</button>', '>Confirm crop</button>', s.count('>Confirmar recorte</button>'))
rep("alert('Carga una imagen primero.')", "alert('Load an image first.')")
rep("alert('Carga una imagen de solución primero.')", "alert('Load a solution image first.')")
rep('`Seleccionar imagen — Alternativa ${mcropTargetChoice}`', '`Select image — Choice ${mcropTargetChoice}`')
rep('Seleccionar área a insertar', 'Select the area to insert', 2)
rep("'Insertar figura en solución'", "'Insert figure into solution'")
rep('onclick="switchManualCropImg(1)">Imagen 1</button>', 'onclick="switchManualCropImg(1)">Image 1</button>')
rep('onclick="switchManualCropImg(2)">Imagen 2</button>', 'onclick="switchManualCropImg(2)">Image 2</button>')
rep('Arrastra para seleccionar · el recorte se insertará en el enunciado', 'Drag to select · the crop will be inserted into the question text')
rep('>Insertar recorte</button>', '>Insert crop</button>')

# ── Extraction: async job + polling ───────────────────────────────────────────
rep("'Extrayendo…'", "'Extracting…'", 2)
rep("'✓ Solución extraída. Revisa y corrige si es necesario.'", "'✓ Solution extracted. Review and fix it if needed.'")
rep("'✓ Extracción completada. Revisa y corrige si es necesario antes de publicar.'",
    "'✓ Extraction complete. Review and fix it before previewing.'")
rep("'✓ Opciones son imágenes — usa ✂ Adjuntar imagen en cada alternativa (A–E).'",
    "'✓ The choices are images — use ✂ Insert image on each choice (A–E).'")
for mode in [", mode: 'solution'", '']:
    rep(f"""    const res = await fetch('/api/extract', {{
      method: 'POST',
      headers: {{ 'Content-Type': 'application/json' }},
      body: JSON.stringify({{ image: stitched{mode} }})
    }});
    if (!res.ok) {{
      const err = await res.json().catch(() => ({{ error: res.statusText }}));
      throw new Error(err.error || res.statusText);
    }}
    const data = await res.json();""", '    const data = await extractImage(stitched, btn);')
rep('// ── EXTRACTION ─────────────────────────────────────────────', '''// ── EXTRACTION ─────────────────────────────────────────────
// MinerU can keep a job queued for minutes, so the server runs extraction as a
// job: start it, then poll every 3 s (the button shows the elapsed time).
async function extractImage(image, btn) {
  const start = await fetch('/composer_en/api/extract', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ image })
  });
  const job = await start.json().catch(() => ({ error: start.statusText }));
  if (!start.ok) throw new Error(job.error || start.statusText);
  const t0 = Date.now();
  for (;;) {
    await new Promise(r => setTimeout(r, 3000));
    btn.textContent = `Extracting… ${Math.round((Date.now() - t0) / 1000)} s`;
    const res = await fetch('/composer_en/api/extract/' + job.id);
    const st = await res.json().catch(() => ({ error: res.statusText }));
    if (!res.ok) throw new Error(st.error || res.statusText);
    if (st.state === 'done') return st.result;
    if (st.state === 'error') throw new Error(st.error || 'Extraction failed.');
    if (Date.now() - t0 > 6 * 60 * 1000) throw new Error('Extraction is taking too long. Please try again.');
  }
}''')
rep("fetch('/api/status')", "fetch('/composer_en/api/status')")
rep("ready ? 'MinerU listo' : 'Servidor no disponible'", "ready ? 'MinerU ready' : 'Server unavailable'")
rep("textContent = 'Servidor no disponible';", "textContent = 'Server unavailable';")
rep("const _bulkId = new URLSearchParams(location.search).get('bulk_id');",
    "const _bulkId = null; // no bulk editing in the demo")

# ── Taxonomy display labels ───────────────────────────────────────────────────
LABELS = {
    # subjects
    'Aritmética': 'Arithmetic', 'Álgebra': 'Algebra', 'Geometría': 'Geometry', 'Trigonometría': 'Trigonometry',
    'Razonamiento Matemático': 'Mathematical Reasoning', 'Razonamiento Verbal': 'Verbal Reasoning',
    'Comunicación y Lengua': 'Language and Communication', 'Literatura': 'Literature',
    'Historia del Perú': 'History of Peru', 'Historia Universal': 'World History',
    'Geografía del Perú': 'Geography of Peru', 'Educación Cívica': 'Civics', 'Economía': 'Economics',
    'Filosofía': 'Philosophy', 'Psicología': 'Psychology', 'Física': 'Physics', 'Química': 'Chemistry',
    'Biología': 'Biology', 'Inglés': 'English', 'Lógica': 'Logic', 'Actualidad': 'Current Affairs',
    'Cálculo Diferencial': 'Differential Calculus', 'Cálculo Integral': 'Integral Calculus',
    'Álgebra Lineal': 'Linear Algebra', 'Geometría Analítica': 'Analytic Geometry',
    'Probabilidad y Estadística': 'Probability and Statistics',
    # admission type / exam-area
    'Ordinario': 'Regular', 'Traslado': 'Transfer', 'Escolar': 'School', 'Simulacro': 'Practice exam',
    'Área A': 'Area A', 'Área B': 'Area B', 'Área C': 'Area C', 'Área D': 'Area D', 'Área E': 'Area E',
    'Aptitud y Humanidades': 'Aptitude and Humanities', 'Matemática': 'Mathematics', 'Física-Química': 'Physics-Chemistry',
    # topics
    'comprension-de-lectura': 'Reading comprehension', 'relaciones-semantico-textuales': 'Semantic and textual relations',
    'analogias-verbales': 'Verbal analogies', 'redaccion-y-cohesion-textual': 'Writing and textual cohesion',
    'inferencia-y-extrapolacion': 'Inference and extrapolation',
    'problemas-de-cantidad': 'Quantity problems',
    'problemas-de-regularidad-equivalencia-y-cambio': 'Regularity, equivalence and change',
    'problemas-de-forma-movimiento-y-localizacion': 'Shape, movement and location',
    'problemas-de-gestion-de-datos-e-incertidumbre': 'Data and uncertainty',
    'operadores-matematicos': 'Mathematical operators',
    'razones-proporciones-y-porcentajes': 'Ratios, proportions and percentages',
    'interes-mezclas-y-aleaciones': 'Interest, mixtures and alloys', 'sucesiones-y-progresiones': 'Sequences and progressions',
    'estadistica-y-probabilidad': 'Statistics and probability',
    'numeros-divisibilidad-y-fracciones': 'Numbers, divisibility and fractions', 'logica-y-conjuntos': 'Logic and sets',
    'angulos-triangulos-y-poligonos': 'Angles, triangles and polygons', 'circunferencia': 'Circles',
    'proporcionalidad-y-relaciones-metricas': 'Proportionality and metric relations',
    'areas-y-poligonos-regulares': 'Areas and regular polygons', 'geometria-del-espacio': 'Solid geometry',
    'geometria-analitica-basica': 'Basic analytic geometry',
    'ecuaciones-e-inecuaciones': 'Equations and inequalities',
    'sistemas-de-ecuaciones-y-matrices': 'Systems of equations and matrices',
    'polinomios-y-productos-notables': 'Polynomials and special products', 'funciones': 'Functions',
    'funcion-exponencial-y-logaritmica': 'Exponential and logarithmic functions',
    'razones-trigonometricas-y-triangulo-rectangulo': 'Trigonometric ratios and right triangles',
    'circunferencia-trigonometrica': 'Unit circle', 'identidades-trigonometricas': 'Trigonometric identities',
    'ecuaciones-y-resolucion-de-triangulos': 'Equations and solving triangles',
    'funciones-trigonometricas': 'Trigonometric functions',
    'fonologia-y-ortografia': 'Phonology and spelling', 'morfologia-y-sintaxis': 'Morphology and syntax',
    'semantica': 'Semantics', 'comunicacion-y-realidad-linguistica-del-peru': "Communication and Peru's languages",
    'vicios-del-lenguaje': 'Common language errors',
    'literatura-universal-antigua-y-medieval': 'Ancient and medieval world literature',
    'literatura-universal-moderna': 'Modern world literature', 'literatura-espanola': 'Spanish literature',
    'literatura-latinoamericana': 'Latin American literature',
    'literatura-peruana-colonial-y-emancipacion': 'Peruvian literature: colonial and independence',
    'literatura-peruana-republicana-y-contemporanea': 'Peruvian literature: republican and contemporary',
    'introduccion-y-enfoques-psicologicos': 'Introduction and psychological approaches',
    'bases-biologicas-del-comportamiento': 'Biological bases of behavior',
    'procesos-cognitivos-y-aprendizaje': 'Cognitive processes and learning',
    'desarrollo-humano-e-identidad': 'Human development and identity', 'afectividad-y-motivacion': 'Emotion and motivation',
    'derechos-humanos': 'Human rights', 'participacion-ciudadana': 'Civic participation',
    'problemas-de-convivencia-en-el-peru': 'Social coexistence issues in Peru',
    'identidad-e-interculturalidad': 'Identity and interculturality',
    'estructura-y-funciones-del-estado': 'Structure and functions of the State',
    'culturas-prehispanicas-y-tawantinsuyo': 'Pre-Hispanic cultures and the Inca Empire', 'virreinato': 'Viceroyalty',
    'independencia-y-siglo-xix': 'Independence and the 19th century',
    'republica-aristocratica-y-reformismo': 'Aristocratic Republic and reformism',
    'peru-en-las-ultimas-decadas': 'Peru in recent decades', 'historia-universal': 'World history',
    'mundo-antiguo-y-clasico': 'Ancient and classical world', 'edad-media': 'Middle Ages',
    'modernidad-y-revoluciones-burguesas': 'Modernity and bourgeois revolutions', 'siglo-xix-mundial': 'The 19th-century world',
    'siglo-xx-y-contemporaneo': '20th century and contemporary',
    'espacio-geografico-y-cartografia': 'Geographic space and cartography',
    'relieve-y-clima-del-peru': 'Relief and climate of Peru', 'hidrografia-y-recursos-hidricos': 'Hydrography and water resources',
    'biodiversidad-y-recursos-naturales': 'Biodiversity and natural resources',
    'poblacion-y-actividades-economicas': 'Population and economic activities',
    'organizacion-politica-y-geografia-mundial': 'Political organization and world geography',
    'principios-economicos-basicos': 'Basic economic principles', 'mercado-de-bienes-y-factores': 'Goods and factor markets',
    'sector-financiero-y-monetario': 'Financial and monetary sector', 'sector-publico-y-fiscal': 'Public and fiscal sector',
    'sector-externo-y-comercio-internacional': 'External sector and international trade',
    'crecimiento-desarrollo-y-emprendimiento': 'Growth, development and entrepreneurship',
    'filosofia-antigua-moderna-y-contemporanea': 'Ancient, modern and contemporary philosophy',
    'etica-sociedad-y-democracia': 'Ethics, society and democracy',
    'gnoseologia-y-metodo-cientifico': 'Epistemology and the scientific method',
    'teoria-de-la-argumentacion': 'Argumentation theory', 'apreciacion-estetica': 'Aesthetics',
    'mecanica-cinematica-y-dinamica': 'Mechanics: kinematics and dynamics',
    'trabajo-energia-y-momentum': 'Work, energy and momentum', 'oscilaciones-ondas-y-fluidos': 'Oscillations, waves and fluids',
    'termodinamica': 'Thermodynamics', 'electricidad-y-magnetismo': 'Electricity and magnetism',
    'optica-y-fisica-moderna': 'Optics and modern physics',
    'materia-y-estructura-atomica': 'Matter and atomic structure',
    'enlace-nomenclatura-y-estequiometria': 'Bonding, nomenclature and stoichiometry',
    'estados-soluciones-y-equilibrio': 'States, solutions and equilibrium', 'electroquimica': 'Electrochemistry',
    'quimica-organica': 'Organic chemistry', 'recursos-naturales-y-contaminacion': 'Natural resources and pollution',
    'celula-tejidos-y-composicion-quimica': 'Cells, tissues and chemical composition',
    'nutricion-digestion-y-circulacion': 'Nutrition, digestion and circulation',
    'sistemas-excretor-inmunologico-y-endocrino': 'Excretory, immune and endocrine systems',
    'sistema-nervioso-y-reproduccion': 'Nervous system and reproduction',
    'genetica-evolucion-y-biodiversidad': 'Genetics, evolution and biodiversity',
    'ecologia-salud-y-recursos-naturales': 'Ecology, health and natural resources',
    'limites-y-continuidad': 'Limits and continuity', 'la-derivada-y-reglas-de-derivacion': 'The derivative and its rules',
    'aplicaciones-de-la-derivada': 'Applications of the derivative',
    'la-integral-definida-y-metodos-de-integracion': 'The definite integral and integration methods',
    'funciones-trascendentes': 'Transcendental functions', 'aplicaciones-de-la-integral': 'Applications of the integral',
    'matrices-y-determinantes': 'Matrices and determinants', 'sistemas-de-ecuaciones-lineales': 'Systems of linear equations',
    'espacios-vectoriales': 'Vector spaces', 'valores-y-vectores-propios': 'Eigenvalues and eigenvectors',
    'la-recta-en-el-plano': 'Lines in the plane', 'circunferencia-y-conicas': 'Circles and conics',
    'geometria-analitica-del-espacio': 'Analytic geometry in space',
    'probabilidad-basica-y-combinatoria': 'Basic probability and combinatorics',
    'variable-aleatoria-y-esperanza-matematica': 'Random variables and expected value',
    'estadistica-descriptiva': 'Descriptive statistics', 'distribuciones-de-probabilidad': 'Probability distributions',
    'comprension-lectora-ingles': 'Reading comprehension (English)', 'gramatica-basica': 'Basic grammar',
    'vocabulario': 'Vocabulary',
    'proposiciones-y-formalizacion': 'Propositions and formalization',
    'tablas-de-verdad-y-tautologia': 'Truth tables and tautologies', 'inferencia-y-silogismo': 'Inference and syllogisms',
    'politica-nacional': 'National politics', 'politica-internacional': 'International politics',
    'economia-actual': 'Current economy', 'ciencia-y-tecnologia': 'Science and technology',
}
# Every subject and topic in the composer must have a label.
taxonomy = s[s.index('const TEMAS = {'):s.index('const TIPO_AREA = {')]
taxonomy = '\n'.join(l for l in taxonomy.splitlines() if not l.strip().startswith('//'))
for key in re.findall(r"'([^']+)'", taxonomy):
    if key in ('UNMSM', 'UNI'):
        continue
    assert key in LABELS, f'no English label for {key!r}'
# Python's repr of these strings is also a valid JS string literal.
labels_js = ',\n'.join(f'  {k!r}: {v!r}' for k, v in LABELS.items())
rep('document.getElementById(\'university\').addEventListener(\'change\', function() {', f'''// English display labels; option values stay the Spanish taxonomy keys.
const LABEL_EN = {{
{labels_js}
}};
const en = v => LABEL_EN[v] || v;

document.getElementById('university').addEventListener('change', function() {{''')
rep('opt.value = m; opt.textContent = m;', 'opt.value = m; opt.textContent = en(m);')
rep('opt.value = v; opt.textContent = v;', 'opt.value = v; opt.textContent = en(v);')
rep('group.label = tema;', 'group.label = en(tema);')
rep('opt.value = s; opt.textContent = s;', 'opt.value = s; opt.textContent = en(s);')
rep('const cat = uni && tema ? `${uni} / ${tema}`', 'const cat = uni && tema ? `${uni} / ${en(tema)}`')
rep('modEl.textContent = modalidad;', 'modEl.textContent = en(modalidad);')
rep('taEl.textContent = tipoArea;', 'taEl.textContent = en(tipoArea);')
rep('subTemas.map(t => `<span class="tag">${t}</span>`)', 'subTemas.map(t => `<span class="tag">${en(t)}</span>`)')

# ── "Publish" opens the preview as an overlay; nothing is sent anywhere ───────
cut('async function doPublish() {', 'async function doPublishLinked() {', '''// Demo: instead of publishing, show the finished question as a layer over the
// page (a copy of the live preview, without the editing buttons).
async function doPublish() {
  const nodes = [document.getElementById('prev-body'), document.getElementById('prev-choices'), document.getElementById('prev-sol-body')];
  if (window.MathJax?.typesetPromise) await MathJax.typesetPromise(nodes.filter(Boolean));
  const target = document.getElementById('preview-overlay-body');
  target.innerHTML = '';
  target.appendChild(document.querySelector('.preview-panel .topic-preview').cloneNode(true));
  if (document.getElementById('chk-solucion').checked) {
    const sol = document.getElementById('prev-sol-wrap').cloneNode(true);
    sol.style.display = '';
    target.appendChild(sol);
  }
  target.querySelectorAll('button').forEach(b => b.remove());
  target.querySelectorAll('[id]').forEach(el => el.removeAttribute('id'));
  document.getElementById('preview-overlay').classList.remove('hidden');
  document.body.style.overflow = 'hidden';
  resetValidation();
}

function closePreviewOverlay() {
  document.getElementById('preview-overlay').classList.add('hidden');
  document.body.style.overflow = '';
}

document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closePreviewOverlay(); });

''')
rep('</style>', '''/* ── DEMO: preview overlay ── */
.preview-overlay { position:fixed; inset:0; background:rgba(0,0,0,.55); z-index:1500; display:flex; align-items:flex-start; justify-content:center; overflow-y:auto; padding:40px 16px; }
.preview-overlay.hidden { display:none; }
.preview-overlay-card { background:#fafafa; border-radius:8px; width:min(760px,100%); padding:20px 24px; box-shadow:0 10px 40px rgba(0,0,0,.3); }
.preview-overlay-head { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:4px; }
.preview-overlay-head h2 { font-size:17px; font-weight:700; color:#1d1d1d; }
.preview-overlay-note { font-size:12px; color:#666; margin-bottom:14px; }
.preview-overlay-close { padding:6px 16px; border-radius:4px; border:1px solid #ccc; background:#fff; font-size:13px; cursor:pointer; }
.preview-overlay-close:hover { border-color:#00529b; color:#00529b; }
</style>''')
rep('</body>', '''<!-- DEMO: preview overlay (opened by "Publish question") -->
<div id="preview-overlay" class="preview-overlay hidden" onclick="if (event.target === this) closePreviewOverlay()">
  <div class="preview-overlay-card" role="dialog" aria-modal="true" aria-labelledby="preview-overlay-title">
    <div class="preview-overlay-head">
      <h2 id="preview-overlay-title">✓ Your question is ready</h2>
      <button class="preview-overlay-close" onclick="closePreviewOverlay()">Close</button>
    </div>
    <div class="preview-overlay-note">This is how it will look once published. Demo mode: nothing was published.</div>
    <div id="preview-overlay-body"></div>
  </div>
</div>

</body>''')

io.open(DST, 'w', encoding='utf-8', newline='\n').write(s)
print('wrote', DST)
