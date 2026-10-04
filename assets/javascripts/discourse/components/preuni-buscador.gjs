import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { ajax } from "discourse/lib/ajax";
import { registrarEvento } from "../lib/preuni-eventos";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import DMultiSelect from "discourse/ui-kit/d-multi-select";

// Replaces the native categorías>/etiquetas> dropdowns + Recientes/En
// tendencia/Categorías tabs on discovery pages (see the __CSS hiding
// .list-controls below) with a 7-facet search across the whole published
// question bank, backed by GET /preuni/buscar and /preuni/opciones
// (app/controllers/preuni_busqueda_controller.rb). Registered at the
// discovery-list-area wrapper outlet -- see
// connectors/discovery-list-area/preuni-buscador-connector.gjs.

const FACETS = [
  { key: "universidad", label: "Universidad" },
  { key: "anio", label: "Año" },
  { key: "convocatoria", label: "Convocatoria" },
  { key: "modalidad", label: "Modalidad" },
  { key: "tipo_area", label: "Tipo/Área" },
  { key: "tema", label: "Tema" },
  { key: "subtema", label: "Sub Tema" },
];

const DIF_LABEL = { facil: "Fácil", medio: "Medio", dificil: "Difícil" };

const CSS = `
.list-controls{display:none}
.preuni-buscador{max-width:1120px;margin:0 auto;padding:8px 4px 40px;box-sizing:border-box}
.preuni-buscador-intro{margin:0 2px 12px;font-size:15px;color:var(--primary-medium,#666)}
.preuni-buscador-panel{
  padding:14px 16px;border-radius:10px;background:var(--primary-very-low,#f6f6f6);
  border:1px solid var(--primary-low,#ddd)
}
.preuni-buscador-filtros{
  display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px 12px
}
.preuni-buscador-facet{display:flex;flex-direction:column;gap:3px;min-width:0}
.preuni-buscador-facet label{font-size:12px;font-weight:600;color:var(--primary-medium,#666)}
.preuni-buscador-facet .d-multi-select-trigger{width:100%;box-sizing:border-box}
.preuni-buscador-limpiar-fila{display:flex;justify-content:flex-end;margin-top:10px}
.preuni-buscador-limpiar{
  border:1px solid #00529b;background:transparent;color:#00529b;border-radius:6px;padding:7px 14px;
  font-size:13px;font-weight:600;cursor:pointer
}
.preuni-buscador-limpiar:hover{background:#eaf0f9}
.preuni-buscador-resumen{padding:14px 2px 10px;font-size:14px;color:var(--primary-medium,#666)}
.preuni-buscador-resumen strong{color:var(--primary,#222)}
.preuni-buscador-lista{display:flex;flex-direction:column;gap:10px}
.preuni-buscador-item{
  display:block;padding:14px 16px;border-radius:10px;background:var(--secondary,#fff);
  border:1px solid var(--primary-low,#ddd);text-decoration:none;color:inherit;
  transition:border-color .15s
}
.preuni-buscador-item:hover{border-color:#00529b}
.preuni-buscador-item-meta{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-bottom:6px}
.preuni-buscador-item-uni{
  font-size:11px;font-weight:700;letter-spacing:.03em;color:#00529b;background:#eaf0f9;
  border:1px solid #cdd9ec;border-radius:4px;padding:1px 7px
}
.preuni-buscador-item-tema{font-size:12px;color:var(--primary-medium,#666)}
.preuni-buscador-item-num{
  display:inline-block;font-size:12px;font-weight:600;color:#2b3f6b;background:#e4e8f2;
  border:1px solid #c8d2e8;border-radius:4px;padding:0 7px;margin-right:2px
}
.preuni-buscador-item-dif{
  font-size:11px;font-weight:600;padding:1px 7px;border-radius:4px;margin-left:auto
}
.preuni-buscador-item-dif[data-dif="facil"]{background:#d4edda;color:#155724;border:1px solid #c3e6cb}
.preuni-buscador-item-dif[data-dif="medio"]{background:#fff3cd;color:#856404;border:1px solid #ffeeba}
.preuni-buscador-item-dif[data-dif="dificil"]{background:#f8d7da;color:#721c24;border:1px solid #f5c6cb}
.preuni-buscador-item-titulo{font-weight:600;color:var(--primary,#222);line-height:1.4}
.preuni-buscador-vacio{padding:24px;text-align:center;color:var(--primary-medium,#666)}
.preuni-buscador-mas-fila{display:flex;justify-content:center;margin-top:14px}
.preuni-buscador-mas{
  border:1px solid #00529b;background:#00529b;color:#fff;border-radius:6px;padding:9px 18px;
  font-size:14px;font-weight:600;cursor:pointer
}
.preuni-buscador-mas:disabled{opacity:.6;cursor:default}
`;

class Facet extends Component {
  get loadFn() {
    return async (term) => {
      const t = (term || "").toLowerCase();
      return (this.args.options || [])
        .filter((o) => String(o).toLowerCase().includes(t))
        .map((o) => ({ id: String(o), name: String(o) }));
    };
  }

  <template>
    <div class="preuni-buscador-facet">
      <label>{{@label}}</label>
      <DMultiSelect
        @label={{@label}}
        @loadFn={{this.loadFn}}
        @matchTriggerMinWidth={{true}}
        @onChange={{@onChange}}
        @selection={{@selection}}
      >
        <:selection as |item|>{{item.name}}</:selection>
        <:result as |item|>{{item.name}}</:result>
      </DMultiSelect>
    </div>
  </template>
}

export default class PreuniBuscador extends Component {
  @tracked opciones = {};
  @tracked seleccion = FACETS.reduce((acc, f) => ({ ...acc, [f.key]: [] }), {});
  @tracked items = [];
  @tracked total = 0;
  @tracked truncado = false;
  @tracked cargando = true;
  @tracked cargandoMas = false;
  siguiente = 0;
  // A response is applied only if no newer search started meanwhile (filters
  // changed while a page was still loading).
  consulta = 0;

  constructor(owner, args) {
    super(owner, args);
    if (!document.getElementById("preuni-buscador-styles")) {
      const s = document.createElement("style");
      s.id = "preuni-buscador-styles";
      s.textContent = CSS;
      document.head.appendChild(s);
    }
    this.cargarOpciones();
    this.buscar();
  }

  async cargarOpciones() {
    try {
      this.opciones = await ajax("/preuni/opciones");
    } catch {
      this.opciones = {};
    }
  }

  filtrosParaConsulta() {
    const data = {};
    FACETS.forEach(({ key }) => {
      const vals = this.seleccion[key].map((o) => o.id);
      if (vals.length) {
        data[`${key}[]`] = vals;
      }
    });
    return data;
  }

  conEtiqueta(items) {
    return items.map((item) => ({
      ...item,
      dificultadLabel: DIF_LABEL[item.dificultad],
    }));
  }

  async buscar() {
    const consulta = ++this.consulta;
    this.cargando = true;
    this.cargandoMas = false;
    try {
      const res = await ajax("/preuni/buscar", { data: this.filtrosParaConsulta() });
      if (consulta !== this.consulta) {
        return;
      }
      this.items = this.conEtiqueta(res.items);
      this.total = res.total;
      this.truncado = res.truncado;
      this.siguiente = res.siguiente ?? res.items.length;
    } catch {
      if (consulta !== this.consulta) {
        return;
      }
      this.items = [];
      this.total = 0;
      this.truncado = false;
    }
    this.cargando = false;
  }

  @action
  async verMas() {
    const consulta = this.consulta;
    this.cargandoMas = true;
    try {
      const res = await ajax("/preuni/buscar", {
        data: { ...this.filtrosParaConsulta(), offset: this.siguiente },
      });
      if (consulta !== this.consulta) {
        return;
      }
      this.items = [...this.items, ...this.conEtiqueta(res.items)];
      this.total = res.total;
      this.truncado = res.truncado;
      this.siguiente = res.siguiente ?? this.siguiente + res.items.length;
    } catch {
      // keep what is shown; the button stays so the student can retry
    }
    if (consulta === this.consulta) {
      this.cargandoMas = false;
    }
  }

  get restantes() {
    return Math.max(0, this.total - this.items.length);
  }

  get facetConfigs() {
    return FACETS.map((f) => ({
      key: f.key,
      label: f.label,
      options: this.opciones[f.key] || [],
      selection: this.seleccion[f.key],
    }));
  }

  get hayFiltros() {
    return FACETS.some((f) => this.seleccion[f.key].length > 0);
  }

  get totalLabel() {
    return this.total === 1 ? "pregunta encontrada" : "preguntas encontradas";
  }

  @action
  cambiarFacet(key, selection) {
    const antes = this.seleccion[key].map((o) => o.id);
    const valores = selection.map((o) => o.id);
    this.seleccion = { ...this.seleccion, [key]: selection };
    registrarEvento("busqueda_filtro", {
      datos: {
        faceta: key,
        agregados: valores.filter((v) => !antes.includes(v)),
        valores,
      },
    });
    discourseDebounce(this, this.buscar, INPUT_DELAY);
  }

  @action
  clickResultado(item, posicion) {
    const filtros = {};
    FACETS.forEach(({ key }) => {
      if (this.seleccion[key].length) {
        filtros[key] = this.seleccion[key].map((o) => o.id);
      }
    });
    registrarEvento("busqueda_resultado_click", {
      topicId: item.topic_id,
      postId: item.post_id,
      datos: { posicion: posicion + 1, total: this.total, filtros },
    });
  }

  @action
  limpiar() {
    this.seleccion = FACETS.reduce((acc, f) => ({ ...acc, [f.key]: [] }), {});
    this.buscar();
  }

  <template>
    <div class="preuni-buscador">
      <p class="preuni-buscador-intro">Selecciona los ejercicios que necesites y empieza a practicar…</p>

      <div class="preuni-buscador-panel">
        <div class="preuni-buscador-filtros">
          {{#each this.facetConfigs as |f|}}
            <Facet
              @label={{f.label}}
              @onChange={{fn this.cambiarFacet f.key}}
              @options={{f.options}}
              @selection={{f.selection}}
            />
          {{/each}}
        </div>
        {{#if this.hayFiltros}}
          <div class="preuni-buscador-limpiar-fila">
            <button
              class="preuni-buscador-limpiar"
              type="button"
              {{on "click" this.limpiar}}
            >Limpiar filtros</button>
          </div>
        {{/if}}
      </div>

      <div class="preuni-buscador-resumen">
        {{#if this.cargando}}
          Buscando…
        {{else}}
          <strong>{{this.total}}</strong>
          {{this.totalLabel}}
          {{#if this.truncado}}
            — mostrando {{this.items.length}}
          {{/if}}
        {{/if}}
      </div>

      <div class="preuni-buscador-lista">
        {{#each this.items as |item i|}}
          <a
            class="preuni-buscador-item"
            href={{item.url}}
            {{on "click" (fn this.clickResultado item i)}}
          >
            <div class="preuni-buscador-item-meta">
              <span class="preuni-buscador-item-uni">{{item.universidad}}</span>
              <span class="preuni-buscador-item-tema">{{item.tema}}</span>
              {{#if item.dificultadLabel}}
                <span
                  class="preuni-buscador-item-dif"
                  data-dif={{item.dificultad}}
                >{{item.dificultadLabel}}</span>
              {{/if}}
            </div>
            <div class="preuni-buscador-item-titulo">
              {{#if item.numero}}<span class="preuni-buscador-item-num">N.º {{item.numero}}</span>{{/if}}{{item.titulo}}
            </div>
          </a>
        {{else}}
          {{#unless this.cargando}}
            <div class="preuni-buscador-vacio">No se encontraron preguntas con estos filtros.</div>
          {{/unless}}
        {{/each}}
      </div>

      {{#if this.truncado}}
        {{#unless this.cargando}}
          <div class="preuni-buscador-mas-fila">
            <button
              class="preuni-buscador-mas"
              type="button"
              disabled={{this.cargandoMas}}
              {{on "click" this.verMas}}
            >
              {{#if this.cargandoMas}}
                Cargando…
              {{else}}
                Ver más preguntas ({{this.restantes}} restantes)
              {{/if}}
            </button>
          </div>
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
