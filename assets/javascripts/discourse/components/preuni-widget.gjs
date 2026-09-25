import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import { fn, concat } from "@ember/helper";
import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { eq, not } from "discourse/truth-helpers";
import DiscourseURL from "discourse/lib/url";

const PREUNI_CSS = `
.preuni-widget{margin:0 0 1.2rem 0}
.preuni-pill{
  background:#eaf0f9;border:1px solid #cdd9ec;border-radius:50px;
  display:flex;align-items:center;padding:8px 14px;gap:0;
  min-height:56px;margin-bottom:6px;user-select:none;width:100%;box-sizing:border-box
}
.preuni-pill-btn{
  width:38px;height:38px;border-radius:50%;border:none;cursor:pointer;
  display:flex;align-items:center;justify-content:center;
  font-size:15px;flex-shrink:0;transition:background .15s,transform .1s
}
.preuni-pill-btn:active{transform:scale(.93)}
.preuni-pill-btn.play   {background:#00529b;color:#fff}
.preuni-pill-btn.running{background:#6c757d;color:#fff;cursor:default}
.preuni-pill-btn.correct{background:#00a86b;color:#fff;cursor:default}
.preuni-pill-btn.wrong  {background:#e53e3e;color:#fff;cursor:default}
.preuni-pill-time{
  font-size:17px;font-weight:700;color:#333;
  min-width:52px;font-variant-numeric:tabular-nums;margin-left:9px
}
.preuni-sep{width:1px;background:#b8cce4;height:30px;margin:0 14px;flex-shrink:0}
.preuni-center{flex:1;display:flex;align-items:center;justify-content:center;min-width:0}
.preuni-idle-text{font-size:13px;color:#8a9ab5}
.preuni-choices{display:flex;gap:7px}
.preuni-c-btn{
  width:38px;height:38px;border-radius:8px;border:2px solid #b0c4de;
  background:#fff;font-size:13px;font-weight:700;color:#3a4a60;cursor:pointer;
  transition:all .15s;display:flex;align-items:center;justify-content:center
}
.preuni-c-btn:hover{border-color:#00529b;color:#00529b;background:#f0f6fc;transform:translateY(-1px)}
.preuni-dist{display:flex;gap:5px;align-items:stretch}
.preuni-dist-item{
  display:flex;flex-direction:column;align-items:center;justify-content:center;
  gap:1px;padding:5px 9px;border-radius:7px;
  border:2px solid transparent;background:#fff;min-width:46px
}
.preuni-dist-letter{font-size:10px;font-weight:700;color:#888}
.preuni-dist-pct{font-size:12px;font-weight:600;color:#333}
.preuni-dist-item.is-correct{background:#d4edda}
.preuni-dist-item.is-correct .preuni-dist-letter,
.preuni-dist-item.is-correct .preuni-dist-pct{color:#155724;font-weight:800}
.preuni-dist-item.is-wrong-pick{border:2px solid #1a1a1a;background:#fff}
.preuni-dist-item.is-wrong-pick .preuni-dist-letter,
.preuni-dist-item.is-wrong-pick .preuni-dist-pct{color:#e53e3e;font-weight:700}
.preuni-dist-item.is-correct.is-selected{border:2px solid #1a1a1a}
.preuni-log-btn{
  width:38px;height:38px;border-radius:50%;background:#00529b;color:#fff;
  border:none;cursor:pointer;font-size:15px;flex-shrink:0;margin-left:14px;
  display:flex;align-items:center;justify-content:center;transition:opacity .15s
}
.preuni-log-btn:hover{opacity:.8}
.preuni-spoiler-wrap{margin-top:2px;margin-bottom:14px}
.preuni-spoiler-btn{
  display:flex;align-items:center;gap:8px;width:100%;
  padding:8px 14px;border-radius:6px;border:1px solid #ddd;
  background:#fafafa;cursor:pointer;font-size:13px;color:#555;
  transition:all .15s;text-align:left
}
.preuni-spoiler-btn:hover{border-color:#aaa;background:#f0f0f0}
.preuni-spoiler-content{
  margin-top:8px;padding:14px 16px;
  background:#f9fff9;border-radius:6px;border:1px solid #a8d5b5;font-size:14px
}
.preuni-spoiler-clave{font-weight:800;color:#155724;font-size:15px}
.preuni-error-msg{
  margin-top:6px;padding:6px 12px;border-radius:6px;
  background:#fff5f5;border:1px solid #f5a8ad;color:#721c24;font-size:13px
}
.preuni-meta-row{
  margin:0 0 6px var(--topic-avatar-width,45px);
  max-width:calc(var(--topic-body-width) + 2 * var(--topic-body-width-padding));
  display:flex;gap:6px;flex-wrap:wrap;align-items:center
}
.preuni-meta-tag{
  font-size:11px;font-weight:600;color:#5a6a82;
  background:#edf2f8;border:1px solid #c8d6e8;
  border-radius:4px;padding:2px 8px;white-space:nowrap
}
.preuni-meta-num{color:#00529b;background:#e8f0fc;border-color:#b8ccf0;font-weight:700}
.preuni-login-prompt{
  font-size:13px;color:#00529b;text-decoration:none;font-weight:600;
  display:flex;align-items:center;gap:5px
}
.preuni-login-prompt:hover{text-decoration:underline}

@media (max-width: 600px){
  .preuni-pill{padding:6px 8px;min-height:44px}
  .preuni-pill-btn{width:30px;height:30px;font-size:13px}
  .preuni-pill-time{font-size:13px;min-width:38px;margin-left:5px}
  .preuni-sep{margin:0 6px;height:22px}
  .preuni-center{overflow-x:auto;-webkit-overflow-scrolling:touch;scrollbar-width:none;justify-content:flex-start}
  .preuni-center::-webkit-scrollbar{display:none}
  .preuni-choices{gap:4px}
  .preuni-c-btn{width:28px;height:28px;font-size:12px;flex-shrink:0}
  .preuni-dist{gap:3px}
  .preuni-dist-item{padding:4px 6px;min-width:34px;flex-shrink:0}
  .preuni-idle-text{font-size:12px;white-space:nowrap}
  .preuni-log-btn{width:30px;height:30px;font-size:13px;margin-left:6px;flex-shrink:0}
}
`;

export default class PreuniWidget extends Component {
  @service currentUser;

  @tracked estado = "idle";    // idle | corriendo | respondido
  @tracked segundos = 0;
  @tracked seleccion = null;
  @tracked correcto = null;
  @tracked clave = null;
  @tracked distribucion = null;
  @tracked error = null;
  @tracked loginGate = false;

  _timer = null;
  _inicio = null;
  _topicId = null;  // plain field — not tracked, used to detect SPA navigation
  _resizeObs = null;
  _destroyed = false;
  letras = ["A", "B", "C", "D", "E"];

  constructor(owner, args) {
    super(owner, args);
    if (!document.getElementById("preuni-styles")) {
      const s = document.createElement("style");
      s.id = "preuni-styles";
      s.textContent = PREUNI_CSS;
      document.head.appendChild(s);
    }
  }

  // Two mount modes: @topic (root question, one instance reused across SPA
  // topic navigation — needs the manual identity/reset dance below) or @post
  // (an additional linked question inside a reading-passage cluster; Ember
  // naturally creates/destroys one instance per rendered post, so none of
  // that SPA-navigation bookkeeping is needed).
  get postMode() { return !!this.args.post; }

  get fields() {
    if (this.postMode) {
      return {
        clave: this.args.post?.preuni_clave,
        numero: this.args.post?.preuni_numero,
        dificultad: this.args.post?.preuni_dificultad,
        total_intentos: this.args.post?.preuni_total_intentos,
      };
    }
    return this.args.topic?.preuni_fields;
  }

  // The id every server call keys off. Root question: the topic's first post.
  get postId() {
    if (this.postMode) return this.args.post?.id;
    return this.args.topic?.postStream?.firstPostId ?? null;
  }

  get esPreuni() {
    if (this.postMode) {
      if (!this._postModeInit) {
        this._postModeInit = true;
        schedule("afterRender", this, () => {
          this._cargarPrevio(this.postId);
          this._adjustWidth();
          this._injectDificultadChip();
        });
      }
      return !!this.fields?.clave;
    }

    // Detects SPA topic changes and resets state — schedule keeps mutation out of render
    const id = this.args.topic?.id;
    if (id && id !== this._topicId) {
      this._topicId = id;
      schedule("afterRender", this, () => {
        this._resetState();
        this._cargarPrevio(this.postId);
        if (this._resizeObs) { this._resizeObs.disconnect(); this._resizeObs = null; }
        this._adjustWidth();
        this._injectDificultadChip();
      });
    }
    return !!this.fields?.clave;
  }

  // Topic-mode: one chip, injected into the topic-category row (there's only
  // ever one root question per topic). Post-mode: one chip PER linked
  // question, injected right after that question's own widget instance —
  // needs its own id so multiple chips on one page don't collide or get
  // wiped by each other's `#id?.remove()` call.
  _injectDificultadChip() {
    const chipId = this.postMode ? `preuni-dificultad-chip-${this.postId}` : 'preuni-dificultad-chip';
    document.getElementById(chipId)?.remove();
    const dif      = this.fields?.dificultad;
    const intentos = this.fields?.total_intentos;
    if (!dif || !intentos) return;
    const tagContainer = this.postMode
      ? document.getElementById(`preuni-widget-${this.postId}`)
      : document.querySelector('.topic-category');
    if (!tagContainer) return;
    const MAP = {
      facil:   { bg: '#d4edda', color: '#155724', border: '#c3e6cb', label: 'Fácil'   },
      medio:   { bg: '#fff3cd', color: '#856404', border: '#ffeeba', label: 'Medio'   },
      dificil: { bg: '#f8d7da', color: '#721c24', border: '#f5c6cb', label: 'Difícil' },
    };
    const c = MAP[dif];
    if (!c) return;
    const chip = document.createElement('span');
    chip.id = chipId;
    chip.style.cssText = `display:inline-flex;align-items:center;gap:4px;padding:2px 8px;border-radius:4px;font-size:12px;font-weight:600;background:${c.bg};color:${c.color};border:1px solid ${c.border};vertical-align:middle;margin-left:6px`;
    chip.textContent = `${c.label} · ${intentos} intentos`;
    tagContainer.appendChild(chip);
  }

  // Measure actual post body rect and apply to pill — works at any viewport/breakpoint.
  // In post-mode there can be several widget instances on one page (one per
  // linked question), so we must scope to THIS instance's own containing
  // post, not just grab the first ".topic-post" on the page.
  _adjustWidth(attempt = 0) {
    if (this._destroyed) return;
    const widget = this.postMode
      ? document.getElementById(`preuni-widget-${this.postId}`)
      : document.querySelector('.preuni-widget');
    const postEl = widget?.closest('.topic-post');
    const body = postEl?.querySelector('.topic-body') ?? (this.postMode ? null : document.querySelector('.topic-post .topic-body'));
    if (!body || !widget || !widget.parentElement) {
      if (attempt < 5) setTimeout(() => this._adjustWidth(attempt + 1), 100);
      return;
    }
    const parentRect = widget.parentElement.getBoundingClientRect();
    const bodyRect = body.getBoundingClientRect();
    widget.style.marginLeft = Math.max(0, bodyRect.left - parentRect.left) + 'px';
    widget.style.maxWidth = bodyRect.width + 'px';
    if (!this._resizeObs) {
      this._resizeObs = new ResizeObserver(() => this._adjustWidth());
      this._resizeObs.observe(body);
    }
  }

  _resetState() {
    clearInterval(this._timer);
    this.estado = "idle";
    this.segundos = 0;
    this.seleccion = null;
    this.correcto = null;
    this.clave = null;
    this.distribucion = null;
    this.error = null;
    this.loginGate = false;
  }

  async _cargarPrevio(postId) {
    if (!this.fields?.clave || !postId) return;
    try {
      const data = await ajax(`/preuni/distribucion/${postId}`);
      if (!this.postMode && this._topicId !== this.args.topic?.id) return;  // navigated away before response
      if (data.mi_respuesta) {
        this.clave = this.fields.clave;
        this.seleccion = data.mi_respuesta;
        this.distribucion = data.distribucion;
        this.correcto = data.mi_respuesta === this.clave;
        this.estado = "respondido";
      }
    } catch (_) {
      // not logged in or no previous answer — stay idle
    }
  }

  get timerDisplay() {
    const m = String(Math.floor(this.segundos / 60)).padStart(2, "0");
    const s = String(this.segundos % 60).padStart(2, "0");
    return m + ":" + s;
  }

  get pillBtnClass() {
    if (this.estado === "idle") return "preuni-pill-btn play";
    if (this.estado === "corriendo") return "preuni-pill-btn running";
    return this.correcto ? "preuni-pill-btn correct" : "preuni-pill-btn wrong";
  }

  get pillBtnIcon() {
    if (this.estado === "idle") return "▶";
    if (this.estado === "corriendo") return "⏸";
    return this.correcto ? "✓" : "✗";
  }

  get barras() {
    if (!this.distribucion) return [];
    const clave = this.clave || this.fields?.clave;
    return this.letras.map((l) => {
      const pct = this.distribucion[l]?.pct ?? 0;
      const isCorrect = l === clave;
      const isSelected = l === this.seleccion;
      let clase = "preuni-dist-item";
      if (isCorrect) clase += " is-correct";
      if (isSelected && !isCorrect) clase += " is-wrong-pick";
      if (isCorrect && isSelected) clase += " is-selected";
      return { letra: l, pct, esClave: isCorrect, clase };
    });
  }

  @action
  handlePlay() {
    if (this.estado !== "idle") return;
    this.error = null;
    this.estado = "corriendo";
    this._inicio = Date.now();
    this._timer = setInterval(() => {
      this.segundos = Math.floor((Date.now() - this._inicio) / 1000);
    }, 1000);
  }

  @action
  async responder(letra) {
    if (this.estado !== "corriendo" || this.seleccion) return;
    clearInterval(this._timer);
    if (!this.currentUser) {
      this.seleccion = letra;
      this.loginGate = true;
      return;
    }
    this.seleccion = letra;
    try {
      const data = await ajax("/preuni/responder", {
        type: "POST",
        data: {
          post_id: this.postId,
          respuesta: letra,
          tiempo_segundos: this.segundos,
        },
      });
      this.correcto = data.correcto;
      this.clave = data.clave;
      this.distribucion = data.distribucion;
      this.estado = "respondido";
    } catch (e) {
      const msg = e.jqXHR?.responseJSON?.error || "";
      if (msg === "Ya respondiste esta pregunta") {
        try {
          const dist = await ajax(`/preuni/distribucion/${this.postId}`);
          this.clave = this.fields.clave;
          this.seleccion = dist.mi_respuesta || letra;
          this.correcto = this.seleccion === this.clave;
          this.distribucion = dist.distribucion;
          this.estado = "respondido";
        } catch (_) {
          this.error = "Error al cargar resultados";
          this.seleccion = null;
        }
      } else {
        this.error = msg || "Error al registrar respuesta";
        this.seleccion = null;
      }
    }
  }

  @action
  handleLog() {
    // The log is a personal page: signed-out users are sent to log in, like
    // the other gated features.
    if (!this.currentUser) {
      window.location.href = "/login";
      return;
    }
    DiscourseURL.routeTo(`/errores?pregunta=${this.postId}`);
  }

  willDestroy() {
    this._destroyed = true;
    clearInterval(this._timer);
    if (this._resizeObs) { this._resizeObs.disconnect(); this._resizeObs = null; }
    document.getElementById('preuni-dificultad-chip')?.remove();
    super.willDestroy(...arguments);
  }

  <template>
    {{#if this.esPreuni}}
      <div class="preuni-widget" id={{if this.postMode (concat "preuni-widget-" this.postId)}}>

        {{! ── PILL ── }}
        <div class="preuni-pill">

          {{! Left: status button }}
          <button
            type="button"
            class={{this.pillBtnClass}}
            {{on "click" this.handlePlay}}
          >{{this.pillBtnIcon}}</button>

          {{! Timer }}
          <span class="preuni-pill-time">{{this.timerDisplay}}</span>

          {{! Left separator }}
          <div class="preuni-sep"></div>

          {{! Center zone }}
          <div class="preuni-center">
            {{#if (eq this.estado "idle")}}
              <span class="preuni-idle-text">¿Listo? Inicia el cronómetro</span>

            {{else if this.loginGate}}
              <a href="/login" class="preuni-login-prompt">
                🔒 Seleccionaste {{this.seleccion}} — inicia sesión para ver si acertaste
              </a>

            {{else if (eq this.estado "corriendo")}}
              <div class="preuni-choices">
                {{#each this.letras as |l|}}
                  <button
                    type="button"
                    class="preuni-c-btn"
                    {{on "click" (fn this.responder l)}}
                  >{{l}}</button>
                {{/each}}
              </div>

            {{else}}
              <div class="preuni-dist">
                {{#each this.barras as |b|}}
                  <div class={{b.clase}}>
                    <span class="preuni-dist-letter">{{b.letra}}</span>
                    <span class="preuni-dist-pct">{{b.pct}}%{{if b.esClave " ✓" ""}}</span>
                  </div>
                {{/each}}
              </div>
            {{/if}}
          </div>

          {{! Right separator — hidden in idle }}
          {{#if (not (eq this.estado "idle"))}}
            <div class="preuni-sep"></div>
          {{/if}}

          {{! Log button }}
          <button
            type="button"
            class="preuni-log-btn"
            title="Registro de errores"
            {{on "click" this.handleLog}}
          >📋</button>

        </div>

        {{! ── ERROR ── }}
        {{#if this.error}}
          <div class="preuni-error-msg">{{this.error}}</div>
        {{/if}}

      </div>
    {{/if}}
  </template>
}
