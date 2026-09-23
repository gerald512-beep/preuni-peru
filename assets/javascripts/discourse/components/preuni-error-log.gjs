import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { eq } from "discourse/truth-helpers";

const CSS = `
.preuni-el-page{
  max-width:1120px;margin:0 auto;padding:8px 4px 40px;box-sizing:border-box;
  display:flex;flex-direction:column;gap:18px;min-width:0
}
.preuni-el-head{display:flex;flex-wrap:wrap;gap:10px 16px;align-items:center;justify-content:space-between}
.preuni-el-head h1{margin:0;font-size:26px}
.preuni-el-head select{margin:0;min-width:180px}
.preuni-el-resumen{
  padding:12px 16px;border-radius:8px;background:#eaf0f9;border:1px solid #cdd9ec;
  color:#1f2d45;font-size:15px;display:flex;flex-direction:column;gap:4px
}
.preuni-el-resumen small{color:#4a5a75;font-size:13px}
.preuni-el-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:14px}
.preuni-el-card{
  background:var(--secondary,#fff);border:1px solid var(--primary-low,#ddd);border-radius:10px;
  padding:16px 18px;display:flex;flex-direction:column;gap:2px;border-top:4px solid #00529b
}
.preuni-el-card.verde{border-top-color:#00a86b}
.preuni-el-card.ambar{border-top-color:#e8a317}
.preuni-el-card.rojo{border-top-color:#e53e3e}
.preuni-el-card b{font-size:30px;line-height:1.15;color:var(--primary,#222)}
.preuni-el-card b small{font-size:14px;font-weight:600;color:var(--primary-medium,#666);margin-left:4px}
.preuni-el-card span{font-size:13px;color:var(--primary-medium,#666)}
.preuni-el-filtros{
  display:flex;flex-wrap:wrap;gap:12px 16px;align-items:end;padding:14px 16px;border-radius:10px;
  background:var(--primary-very-low,#f6f6f6);border:1px solid var(--primary-low,#ddd)
}
.preuni-el-filtros label{
  display:flex;flex-direction:column;gap:3px;font-size:12px;font-weight:600;
  color:var(--primary-medium,#666);flex:1 1 140px;max-width:220px;min-width:0
}
.preuni-el-filtros select{width:100%;min-width:0;margin:0}
.preuni-el-filtros .preuni-el-botones{display:flex;gap:8px;margin-left:auto;flex:0 0 auto}
.preuni-el-btn{
  border:1px solid #00529b;background:#00529b;color:#fff;border-radius:6px;padding:8px 16px;
  font-size:14px;font-weight:600;cursor:pointer
}
.preuni-el-btn:hover{background:#003f78}
.preuni-el-btn.sec{background:transparent;color:#00529b}
.preuni-el-btn.sec:hover{background:#eaf0f9}
.preuni-el-barra{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;justify-content:space-between}
.preuni-el-barra .preuni-el-cuenta{font-size:14px;color:var(--primary-medium,#666)}
.preuni-el-barra .preuni-el-cuenta strong{color:var(--primary,#222)}
.preuni-el-scroll{overflow-x:auto;border:1px solid var(--primary-low,#ddd);border-radius:10px;background:var(--secondary,#fff)}
.preuni-el-tabla{width:100%;border-collapse:collapse;font-size:14px;margin:0}
.preuni-el-tabla th{
  text-align:left;padding:10px 12px;background:var(--primary-very-low,#f6f6f6);
  border-bottom:2px solid var(--primary-low,#ddd);white-space:nowrap;font-size:12px;
  text-transform:uppercase;letter-spacing:.03em;color:var(--primary-medium,#666)
}
.preuni-el-tabla td{padding:10px 12px;border-bottom:1px solid var(--primary-low,#ddd);vertical-align:top}
.preuni-el-tabla tbody tr:last-child td{border-bottom:0}
.preuni-el-tabla tbody tr:hover{background:var(--primary-very-low,#f9f9f9)}
.preuni-el-tabla tr.is-actual{background:#fff8dc;box-shadow:inset 4px 0 0 #e8a317}
.preuni-el-tabla input[type=checkbox]{margin:0}
.preuni-el-ord{
  all:unset;cursor:pointer;display:inline-flex;gap:5px;align-items:center;font:inherit;
  text-transform:inherit;letter-spacing:inherit;color:inherit
}
.preuni-el-ord:hover,.preuni-el-ord:focus-visible{color:#00529b}
.preuni-el-ord i{font-style:normal;font-size:10px;color:#00529b}
.preuni-el-preg{display:flex;flex-direction:column;gap:2px;min-width:200px;max-width:360px}
.preuni-el-titulo,.preuni-el-titulo:visited{
  font-weight:600;color:#00529b;text-decoration:none;
  display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden
}
.preuni-el-titulo:hover{text-decoration:underline}
.preuni-el-num{
  display:inline-block;margin-right:6px;padding:0 7px;border-radius:4px;font-size:12px;
  background:#e4e8f2;color:#2b3f6b;border:1px solid #c8d2e8
}
.preuni-el-origen{font-size:12px;color:var(--primary-medium,#666)}
.preuni-el-res{display:flex;align-items:center;gap:8px;white-space:nowrap}
.preuni-el-icono{
  width:24px;height:24px;border-radius:50%;display:inline-flex;align-items:center;
  justify-content:center;font-size:14px;font-weight:700;color:#fff;flex-shrink:0
}
.preuni-el-icono.ok{background:#00a86b}
.preuni-el-icono.mal{background:#e53e3e}
.preuni-el-res small{color:var(--primary-medium,#666);font-size:12px}
.preuni-el-dif{padding:2px 10px;border-radius:12px;font-size:12px;font-weight:600;white-space:nowrap}
.preuni-el-dif.facil{background:#d4edda;color:#155724}
.preuni-el-dif.medio{background:#fff3cd;color:#856404}
.preuni-el-dif.dificil{background:#f8d7da;color:#721c24}
.preuni-el-tiempo{color:#00a86b;font-weight:700;white-space:nowrap}
.preuni-el-fecha{white-space:nowrap;color:var(--primary-medium,#666)}
.preuni-el-nota{min-width:220px;display:flex;flex-direction:column;gap:2px}
.preuni-el-nota textarea{
  margin:0;width:100%;box-sizing:border-box;resize:vertical;font-size:13px;min-height:0;height:38px;
  transition:height .12s
}
.preuni-el-nota textarea:focus{height:84px}
.preuni-el-estado{min-height:14px;font-size:12px;color:var(--primary-medium,#666)}
.preuni-el-estado.error{color:#c0392b}
.preuni-el-pie{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;justify-content:space-between;font-size:14px;color:var(--primary-medium,#666)}
.preuni-el-pag{display:flex;gap:8px;align-items:center}
.preuni-el-pag button{padding:6px 12px}
.preuni-el-pag button[disabled]{opacity:.45;cursor:default}
.preuni-el-vacio,.preuni-el-error{padding:32px 18px;text-align:center;color:var(--primary-medium,#666)}
.preuni-el-error{color:#c0392b}
.preuni-el-aviso{font-size:12px;color:var(--primary-medium,#666)}
@media (max-width:760px){
  .preuni-el-cards{grid-template-columns:repeat(2,1fr);gap:10px}
  .preuni-el-card{padding:12px 14px}
  .preuni-el-card b{font-size:24px}
  .preuni-el-filtros .preuni-el-botones{margin-left:0;width:100%}
  .preuni-el-filtros label,.preuni-el-filtros select{width:100%}
  .preuni-el-scroll{border:0;background:transparent}
  .preuni-el-tabla thead{display:none}
  .preuni-el-tabla,.preuni-el-tabla tbody,.preuni-el-tabla tr,.preuni-el-tabla td{display:block;width:100%;box-sizing:border-box}
  .preuni-el-tabla tr{
    border:1px solid var(--primary-low,#ddd);border-radius:10px;margin-bottom:12px;padding:6px 0;
    background:var(--secondary,#fff)
  }
  .preuni-el-tabla td{border:0;display:flex;gap:10px;justify-content:space-between;align-items:center;padding:6px 12px}
  .preuni-el-tabla td[data-label]::before{content:attr(data-label);font-size:12px;font-weight:600;color:var(--primary-medium,#666)}
  .preuni-el-tabla td.c-check{display:none}
  .preuni-el-tabla td.c-preg{flex-direction:column;align-items:flex-start}
  .preuni-el-tabla td.c-preg::before,.preuni-el-tabla td.c-nota::before{display:none}
  .preuni-el-preg{max-width:none;min-width:0}
  .preuni-el-nota{min-width:0;width:100%}
}
`;

const RANGOS = [
  { valor: "7", texto: "Últimos 7 días", frase: "los últimos 7 días" },
  { valor: "30", texto: "Últimos 30 días", frase: "los últimos 30 días" },
  { valor: "90", texto: "Últimos 90 días", frase: "los últimos 90 días" },
  { valor: "0", texto: "Todo el tiempo", frase: "todo el tiempo" },
];

const DIFICULTAD = {
  facil: { clase: "facil", texto: "Fácil", rango: 1 },
  medio: { clase: "medio", texto: "Medio", rango: 2 },
  dificil: { clase: "dificil", texto: "Difícil", rango: 3 },
};

const POR_PAGINA = 25;

const FILTROS_VACIOS = { tema: "", universidad: "", dificultad: "", resultado: "todas" };

const COLUMNAS = [
  { campo: "pregunta", texto: "Pregunta" },
  { campo: "resultado", texto: "Resultado" },
  { campo: "tema", texto: "Tema" },
  { campo: "dificultad", texto: "Dificultad" },
  { campo: "tiempo", texto: "Tiempo" },
  { campo: "fecha", texto: "Fecha" },
];

// Sort key per column; null values always sink to the bottom.
const CLAVE_ORDEN = {
  pregunta: (f) => f.ordenPregunta,
  resultado: (f) => (f.correcto ? 1 : 0),
  tema: (f) => f.tema || null,
  dificultad: (f) => f.dificultad?.rango ?? null,
  tiempo: (f) => f.tiempoSeg,
  fecha: (f) => f.fechaMs,
};

function formatoTiempo(segundos) {
  if (segundos === null || segundos === undefined) return "—";
  const s = Math.round(segundos);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

function formatoFecha(iso) {
  return new Date(iso).toLocaleDateString("es-PE", { day: "numeric", month: "short", year: "numeric" });
}

function formatoPuntaje(n) {
  return Number.isInteger(n) ? String(n) : n.toFixed(2).replace(".", ",");
}

function porcentaje(correctas, total) {
  return total ? Math.round((correctas / total) * 100) : null;
}

function celdaCsv(valor) {
  let texto = valor === null || valor === undefined ? "" : String(valor);
  // Spreadsheet formula injection: the note is free text.
  if (/^[=+\-@\t\r]/.test(texto)) texto = `'${texto}`;
  return `"${texto.replace(/"/g, '""')}"`;
}

// One answered question. `nota`/`estado`/`seleccionada` are tracked so the
// textarea, its "Guardado" hint and the checkbox update in place.
class Fila {
  @tracked nota;
  @tracked estado = "";
  @tracked seleccionada = false;

  constructor(d) {
    this.postId = d.post_id;
    this.url = d.url;
    this.titulo = d.titulo;
    this.numero = d.numero;
    this.universidad = d.universidad || "";
    this.convocatoria = d.convocatoria || "";
    this.tema = d.tema || "";
    this.respuesta = d.respuesta;
    this.clave = d.clave;
    this.correcto = d.correcto;
    this.tiempoSeg = d.tiempo_segundos ?? null;
    this.tiempo = formatoTiempo(d.tiempo_segundos);
    this.fechaMs = new Date(d.respondida_en).getTime();
    this.fecha = formatoFecha(d.respondida_en);
    this.dificultad = DIFICULTAD[d.dificultad] || null;
    this.nota = d.nota || "";
    this.origen = [this.universidad, this.convocatoria].filter(Boolean).join(" ");
    this.ordenPregunta = `${this.universidad} ${this.convocatoria} ${String(d.numero ?? "").padStart(4, "0")}`;
  }

  get estadoTexto() {
    if (this.estado === "guardando") return "Guardando…";
    if (this.estado === "guardado") return "Guardado";
    return "";
  }

  get estadoError() {
    return this.estado.startsWith("error:") ? this.estado.slice(6) : "";
  }
}

export default class PreuniErrorLog extends Component {
  @tracked cargando = true;
  @tracked error = null;
  @tracked filas = [];
  @tracked penalizaciones = {};
  @tracked racha = 0;
  @tracked truncado = false;
  @tracked dias = "30";
  @tracked borrador = { ...FILTROS_VACIOS };
  @tracked filtros = { ...FILTROS_VACIOS };
  @tracked ordenCampo = "fecha";
  @tracked ordenDir = "desc";
  @tracked pagina = 0;

  rangos = RANGOS;
  _carga = 0;
  // Row to highlight when arriving from the 📋 button of a question.
  resaltada = Number(this.args.resaltar) || null;
  _yaEnfocada = false;

  constructor(owner, args) {
    super(owner, args);
    if (!document.getElementById("preuni-el-styles")) {
      const s = document.createElement("style");
      s.id = "preuni-el-styles";
      s.textContent = CSS;
      document.head.appendChild(s);
    }
    this.cargar();
  }

  get fraseRango() {
    return RANGOS.find((r) => r.valor === this.dias)?.frase || "";
  }

  get temas() {
    return [...new Set(this.filas.map((f) => f.tema).filter(Boolean))].sort((a, b) => a.localeCompare(b, "es"));
  }

  get universidades() {
    return [...new Set(this.filas.map((f) => f.universidad).filter(Boolean))].sort();
  }

  // Everything below the summary sentence reflects the applied filters.
  get filtradas() {
    const { tema, universidad, dificultad, resultado } = this.filtros;
    const lista = this.filas.filter(
      (f) =>
        (!tema || f.tema === tema) &&
        (!universidad || f.universidad === universidad) &&
        (!dificultad || f.dificultad?.clase === dificultad) &&
        (resultado === "todas" || (resultado === "incorrectas" ? !f.correcto : f.correcto))
    );

    const clave = CLAVE_ORDEN[this.ordenCampo];
    const signo = this.ordenDir === "asc" ? 1 : -1;
    return lista.sort((a, b) => {
      const x = clave(a);
      const y = clave(b);
      if (x === null && y === null) return b.fechaMs - a.fechaMs;
      if (x === null) return 1;
      if (y === null) return -1;
      const cmp = typeof x === "string" ? x.localeCompare(y, "es") : x - y;
      return cmp !== 0 ? cmp * signo : b.fechaMs - a.fechaMs;
    });
  }

  get totalPaginas() {
    return Math.max(1, Math.ceil(this.filtradas.length / POR_PAGINA));
  }

  get paginaVisible() {
    return Math.min(this.pagina, this.totalPaginas - 1);
  }

  get filasPagina() {
    const inicio = this.paginaVisible * POR_PAGINA;
    return this.filtradas.slice(inicio, inicio + POR_PAGINA);
  }

  get rangoTexto() {
    const total = this.filtradas.length;
    if (!total) return "";
    const inicio = this.paginaVisible * POR_PAGINA;
    return `${inicio + 1}–${Math.min(inicio + POR_PAGINA, total)} de ${total}`;
  }

  get paginaMostrada() {
    return this.paginaVisible + 1;
  }

  get sinAnterior() {
    return this.paginaVisible === 0;
  }

  get sinSiguiente() {
    return this.paginaVisible >= this.totalPaginas - 1;
  }

  get resumenTotal() {
    return this.filas.length;
  }

  get resumenPrecision() {
    return porcentaje(this.filas.filter((f) => f.correcto).length, this.filas.length);
  }

  // UNMSM-style score (correctas − penalización × incorrectas) for the period.
  get puntajes() {
    return Object.entries(this.penalizaciones)
      .map(([universidad, penalizacion]) => {
        const propias = this.filas.filter((f) => f.universidad === universidad);
        if (!propias.length) return null;
        const buenas = propias.filter((f) => f.correcto).length;
        const malas = propias.length - buenas;
        return {
          universidad,
          puntaje: formatoPuntaje(buenas - penalizacion * malas),
          penalizacion: formatoPuntaje(penalizacion),
        };
      })
      .filter(Boolean);
  }

  get vistaTotal() {
    return this.filtradas.length;
  }

  get vistaPrecision() {
    const lista = this.filtradas;
    return porcentaje(lista.filter((f) => f.correcto).length, lista.length);
  }

  get vistaTiempo() {
    const tiempos = this.filtradas.map((f) => f.tiempoSeg).filter((t) => t !== null);
    if (!tiempos.length) return "—";
    return formatoTiempo(tiempos.reduce((a, b) => a + b, 0) / tiempos.length);
  }

  get claseTarjetaPrecision() {
    const p = this.vistaPrecision;
    if (p === null) return "";
    return p >= 70 ? "verde" : p >= 40 ? "ambar" : "rojo";
  }

  get columnas() {
    return COLUMNAS.map((c) => {
      const activa = c.campo === this.ordenCampo;
      return {
        ...c,
        aria: activa ? (this.ordenDir === "asc" ? "ascending" : "descending") : "none",
        flecha: activa ? (this.ordenDir === "asc" ? "▲" : "▼") : "",
      };
    });
  }

  get cantidadSeleccionadas() {
    return this.filtradas.filter((f) => f.seleccionada).length;
  }

  get todasSeleccionadas() {
    const lista = this.filtradas;
    return lista.length > 0 && lista.every((f) => f.seleccionada);
  }

  get textoVacio() {
    return this.filas.length
      ? "No hay respuestas con estos filtros."
      : "Todavía no has respondido preguntas en este periodo. Las que falles aparecerán aquí.";
  }

  async cargar() {
    const carga = ++this._carga;
    this.cargando = true;
    this.error = null;
    try {
      const data = await ajax("/preuni/errores", {
        data: { resultado: "todas", dias: this.dias },
      });
      if (carga !== this._carga) return; // a newer range change won
      this.filas = data.items.map((d) => new Fila(d));
      this.penalizaciones = data.penalizaciones || {};
      this.racha = data.racha || 0;
      this.truncado = data.truncado;
      this.cargando = false;
      this.irADestacada();
    } catch (e) {
      if (carga !== this._carga) return;
      this.error = "No se pudo cargar tu registro de errores. Inténtalo de nuevo.";
      this.cargando = false;
    }
  }

  // Jump to the page holding the row we came from and bring it into view.
  irADestacada() {
    if (!this.resaltada || this._yaEnfocada) return;
    const indice = this.filtradas.findIndex((f) => f.postId === this.resaltada);
    if (indice < 0) return;
    this._yaEnfocada = true; // only on arrival; changing the range or sort shouldn't re-scroll
    this.pagina = Math.floor(indice / POR_PAGINA);
    setTimeout(() => {
      document.querySelector(".preuni-el-tabla tr.is-actual")?.scrollIntoView({ block: "center" });
    }, 80);
  }

  @action
  reintentar() {
    this.cargar();
  }

  @action
  cambiarRango(event) {
    this.dias = event.target.value;
    this.pagina = 0;
    this.cargar();
  }

  @action
  cambiarBorrador(campo, event) {
    this.borrador = { ...this.borrador, [campo]: event.target.value };
  }

  @action
  aplicarFiltros() {
    this.filtros = { ...this.borrador };
    this.pagina = 0;
  }

  @action
  restablecerFiltros() {
    this.borrador = { ...FILTROS_VACIOS };
    this.filtros = { ...FILTROS_VACIOS };
    this.pagina = 0;
  }

  @action
  ordenarPor(campo) {
    if (this.ordenCampo === campo) {
      this.ordenDir = this.ordenDir === "asc" ? "desc" : "asc";
    } else {
      this.ordenCampo = campo;
      this.ordenDir = campo === "fecha" ? "desc" : "asc";
    }
    this.pagina = 0;
  }

  @action
  anterior() {
    this.pagina = Math.max(0, this.paginaVisible - 1);
  }

  @action
  siguiente() {
    this.pagina = Math.min(this.totalPaginas - 1, this.paginaVisible + 1);
  }

  @action
  alternarFila(fila, event) {
    fila.seleccionada = event.target.checked;
  }

  @action
  alternarTodas(event) {
    const marcar = event.target.checked;
    this.filtradas.forEach((f) => (f.seleccionada = marcar));
  }

  @action
  descargar() {
    const lista = this.filtradas;
    const elegidas = lista.filter((f) => f.seleccionada);
    const filas = elegidas.length ? elegidas : lista;
    if (!filas.length) return;

    const cabecera = [
      "Pregunta", "Título", "Universidad", "Convocatoria", "Tema", "Resultado", "Tu respuesta",
      "Clave", "Dificultad", "Tiempo (s)", "Fecha", "Nota", "Enlace",
    ];
    const lineas = [cabecera.map(celdaCsv).join(",")];
    for (const f of filas) {
      lineas.push(
        [
          f.numero, f.titulo, f.universidad, f.convocatoria, f.tema,
          f.correcto ? "Correcta" : "Incorrecta", f.respuesta, f.clave, f.dificultad?.texto || "",
          f.tiempoSeg, new Date(f.fechaMs).toISOString().slice(0, 10), f.nota,
          `${window.location.origin}${f.url}`,
        ]
          .map(celdaCsv)
          .join(",")
      );
    }

    // BOM so Excel reads the accents as UTF-8.
    const blob = new Blob(["﻿" + lineas.join("\r\n")], { type: "text/csv;charset=utf-8" });
    const enlace = document.createElement("a");
    enlace.href = URL.createObjectURL(blob);
    enlace.download = `registro-de-errores-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(enlace);
    enlace.click();
    enlace.remove();
    setTimeout(() => URL.revokeObjectURL(enlace.href), 1000);
  }

  @action
  async guardarNota(fila, event) {
    const valor = event.target.value.trim();
    if (valor === (fila.nota || "").trim()) return;
    fila.estado = "guardando";
    try {
      await ajax(`/preuni/errores/${fila.postId}/nota`, {
        type: "PUT",
        data: { nota: valor },
      });
      fila.nota = valor;
      fila.estado = "guardado";
    } catch (e) {
      const msg = e?.jqXHR?.responseJSON?.error || "No se pudo guardar la nota.";
      fila.estado = `error:${msg}`;
    }
  }

  <template>
    <div class="preuni-el-page">
      <header class="preuni-el-head">
        <h1>Tu registro de errores</h1>
        <select aria-label="Periodo" {{on "change" this.cambiarRango}}>
          {{#each this.rangos as |r|}}
            <option value={{r.valor}} selected={{eq r.valor this.dias}}>{{r.texto}}</option>
          {{/each}}
        </select>
      </header>

      {{#if this.cargando}}
        <p class="preuni-el-vacio">Cargando…</p>
      {{else if this.error}}
        <p class="preuni-el-error">
          {{this.error}}
          <button type="button" class="preuni-el-btn sec" {{on "click" this.reintentar}}>Reintentar</button>
        </p>
      {{else}}
        <div class="preuni-el-resumen">
          {{#if this.resumenTotal}}
            <span>Tu precisión es de <strong>{{this.resumenPrecision}} %</strong> en
              <strong>{{this.resumenTotal}}</strong>
              {{if (eq this.resumenTotal 1) "respuesta" "respuestas"}}
              de {{this.fraseRango}}.</span>
            {{#each this.puntajes as |p|}}
              <small>{{p.universidad}}: <strong>{{p.puntaje}}</strong> puntos
                (correctas − {{p.penalizacion}} × incorrectas)</small>
            {{/each}}
          {{else}}
            <span>Todavía no has respondido preguntas en {{this.fraseRango}}.</span>
          {{/if}}
        </div>

        <div class="preuni-el-cards">
          <div class="preuni-el-card">
            <b>{{this.vistaTotal}}</b>
            <span>Respuestas en la vista</span>
          </div>
          <div class="preuni-el-card {{this.claseTarjetaPrecision}}">
            <b>{{if this.vistaTotal this.vistaPrecision "—"}}{{#if this.vistaTotal}}<small>%</small>{{/if}}</b>
            <span>Precisión en la vista</span>
          </div>
          <div class="preuni-el-card verde">
            <b>{{this.vistaTiempo}}</b>
            <span>Tiempo promedio por pregunta</span>
          </div>
          <div class="preuni-el-card ambar">
            <b>{{this.racha}}<small>{{if (eq this.racha 1) "día" "días"}}</small></b>
            <span>Racha de días practicando</span>
          </div>
        </div>

        <div class="preuni-el-filtros">
          <label>
            Tema
            <select {{on "change" (fn this.cambiarBorrador "tema")}}>
              <option value="" selected={{eq this.borrador.tema ""}}>Todos los temas</option>
              {{#each this.temas as |t|}}
                <option value={{t}} selected={{eq this.borrador.tema t}}>{{t}}</option>
              {{/each}}
            </select>
          </label>
          <label>
            Universidad
            <select {{on "change" (fn this.cambiarBorrador "universidad")}}>
              <option value="" selected={{eq this.borrador.universidad ""}}>Todas</option>
              {{#each this.universidades as |u|}}
                <option value={{u}} selected={{eq this.borrador.universidad u}}>{{u}}</option>
              {{/each}}
            </select>
          </label>
          <label>
            Dificultad
            <select {{on "change" (fn this.cambiarBorrador "dificultad")}}>
              <option value="" selected={{eq this.borrador.dificultad ""}}>Todas</option>
              <option value="facil" selected={{eq this.borrador.dificultad "facil"}}>Fácil</option>
              <option value="medio" selected={{eq this.borrador.dificultad "medio"}}>Medio</option>
              <option value="dificil" selected={{eq this.borrador.dificultad "dificil"}}>Difícil</option>
            </select>
          </label>
          <label>
            Resultado
            <select {{on "change" (fn this.cambiarBorrador "resultado")}}>
              <option value="todas" selected={{eq this.borrador.resultado "todas"}}>Todas</option>
              <option value="incorrectas" selected={{eq this.borrador.resultado "incorrectas"}}>Incorrectas</option>
              <option value="correctas" selected={{eq this.borrador.resultado "correctas"}}>Correctas</option>
            </select>
          </label>
          <div class="preuni-el-botones">
            <button type="button" class="preuni-el-btn" {{on "click" this.aplicarFiltros}}>Aplicar filtros</button>
            <button type="button" class="preuni-el-btn sec" {{on "click" this.restablecerFiltros}}>Restablecer</button>
          </div>
        </div>

        <div class="preuni-el-barra">
          <span class="preuni-el-cuenta">
            {{#if this.cantidadSeleccionadas}}
              <strong>{{this.cantidadSeleccionadas}}</strong> seleccionadas
            {{else}}
              <strong>{{this.vistaTotal}}</strong>
              {{if (eq this.vistaTotal 1) "pregunta" "preguntas"}}
            {{/if}}
          </span>
          <button type="button" class="preuni-el-btn sec" {{on "click" this.descargar}}>
            Descargar {{if this.cantidadSeleccionadas "selección" "CSV"}}
          </button>
        </div>

        {{#if this.filasPagina.length}}
          <div class="preuni-el-scroll">
            <table class="preuni-el-tabla">
              <thead>
                <tr>
                  <th class="c-check">
                    <input
                      type="checkbox"
                      aria-label="Seleccionar todas"
                      checked={{this.todasSeleccionadas}}
                      {{on "change" this.alternarTodas}}
                    />
                  </th>
                  {{#each this.columnas as |c|}}
                    <th aria-sort={{c.aria}}>
                      <button type="button" class="preuni-el-ord" {{on "click" (fn this.ordenarPor c.campo)}}>
                        {{c.texto}}<i>{{c.flecha}}</i>
                      </button>
                    </th>
                  {{/each}}
                  <th>Notas</th>
                </tr>
              </thead>
              <tbody>
                {{#each this.filasPagina as |f|}}
                  <tr class={{if (eq f.postId this.resaltada) "is-actual"}}>
                    <td class="c-check">
                      <input
                        type="checkbox"
                        aria-label="Seleccionar pregunta"
                        checked={{f.seleccionada}}
                        {{on "change" (fn this.alternarFila f)}}
                      />
                    </td>
                    <td class="c-preg" data-label="Pregunta">
                      <div class="preuni-el-preg">
                        <a class="preuni-el-titulo" href={{f.url}}>
                          {{#if f.numero}}<span class="preuni-el-num">N.º {{f.numero}}</span>{{/if}}{{f.titulo}}
                        </a>
                        {{#if f.origen}}<span class="preuni-el-origen">{{f.origen}}</span>{{/if}}
                      </div>
                    </td>
                    <td data-label="Resultado">
                      <span class="preuni-el-res">
                        <span
                          class="preuni-el-icono {{if f.correcto 'ok' 'mal'}}"
                          title={{if f.correcto "Correcta" "Incorrecta"}}
                        >{{if f.correcto "✓" "✗"}}</span>
                        <small>Tú: {{f.respuesta}} · Clave: {{f.clave}}</small>
                      </span>
                    </td>
                    <td data-label="Tema">{{if f.tema f.tema "—"}}</td>
                    <td data-label="Dificultad">
                      {{#if f.dificultad}}
                        <span class="preuni-el-dif {{f.dificultad.clase}}">{{f.dificultad.texto}}</span>
                      {{else}}—{{/if}}
                    </td>
                    <td data-label="Tiempo"><span class="preuni-el-tiempo">{{f.tiempo}}</span></td>
                    <td data-label="Fecha"><span class="preuni-el-fecha">{{f.fecha}}</span></td>
                    <td class="c-nota">
                      <label class="preuni-el-nota">
                        <textarea
                          rows="2"
                          maxlength="2000"
                          aria-label="Mi nota: ¿qué falló?"
                          placeholder="¿Qué falló? (solo tú lo ves)"
                          value={{f.nota}}
                          {{on "blur" (fn this.guardarNota f)}}
                        ></textarea>
                        <small class="preuni-el-estado {{if f.estadoError 'error'}}">{{if f.estadoError f.estadoError f.estadoTexto}}</small>
                      </label>
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </div>

          <div class="preuni-el-pie">
            <span>{{this.rangoTexto}}</span>
            <div class="preuni-el-pag">
              <button type="button" class="preuni-el-btn sec" disabled={{this.sinAnterior}} {{on "click" this.anterior}}>‹ Anterior</button>
              <span>Página {{this.paginaMostrada}} de {{this.totalPaginas}}</span>
              <button type="button" class="preuni-el-btn sec" disabled={{this.sinSiguiente}} {{on "click" this.siguiente}}>Siguiente ›</button>
            </div>
          </div>
          {{#if this.truncado}}
            <p class="preuni-el-aviso">Se muestran las 500 respuestas más recientes del periodo. Reduce el periodo para ver las demás.</p>
          {{/if}}
        {{else}}
          <p class="preuni-el-vacio">{{this.textoVacio}}</p>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
