import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import PreuniWidget from "../../components/preuni-widget";
import { registrarEvento } from "../../lib/preuni-eventos";

export default class PreuniClave extends Component {
  @service currentUser;
  @service preuniHilo;
  @tracked mostrarClave = false;

  get hayRespuestas() { return (this.post?.topic?.posts_count || 0) > 1; }

  get eventoRef() {
    return { topicId: this.post?.topic_id, postId: this.post?.id };
  }

  @action
  toggleHilo() {
    this.preuniHilo.toggle();
    if (this.preuniHilo.abierto) {
      registrarEvento("hilo_abierto", this.eventoRef);
    }
  }

  @action
  clickLoginClave() {
    registrarEvento("clave_login_click", this.eventoRef);
  }

  get post() { return this.args.outletArgs?.post; }
  get esPreguntaAdicional() { return this.post?.preuni_post_type === "pregunta_adicional" && this.post?.post_number > 1; }
  // Root post: clave lives on the topic. Linked question: clave lives on
  // that specific post -- "Mostrar clave" needs to work for both, not just
  // the root (it only ever checked post_number === 1 before).
  get clave() {
    if (this.esPreguntaAdicional) return this.post?.preuni_clave;
    return this.post?.topic?.preuni_fields?.clave;
  }
  get esPreuni() {
    if (this.esPreguntaAdicional) return !!this.clave;
    return this.post?.post_number === 1 && !!this.clave;
  }
  get esSolucion() { return this.post?.preuni_post_type === "solucion" && this.post?.post_number > 1; }
  get esUniversitario() { return this.post?.preuni_is_universitario === true; }
  get esEgresado()     { return this.post?.preuni_is_egresado     === true; }
  get esModerador()    { return this.post?.preuni_is_moderador    === true; }

  @action
  toggleClave() {
    this.mostrarClave = !this.mostrarClave;
    if (this.mostrarClave) {
      registrarEvento("clave_mostrada", this.eventoRef);
    }
  }

  <template>
    {{! Linked question: pill first, THEN its "Mostrar clave" spoiler below it.
        Root post: no pill here (it's mounted separately, above all posts),
        just the spoiler -- order below is a no-op for that case. }}
    {{#if this.esPreguntaAdicional}}
      <PreuniWidget @post={{this.post}} />
    {{/if}}
    {{#if this.esPreuni}}
      <div class="preuni-spoiler-wrap">
        {{#if this.currentUser}}
          <button type="button" class="preuni-spoiler-btn" {{on "click" this.toggleClave}}>
            <span>{{if this.mostrarClave "▴" "▾"}}</span>
            Mostrar clave
          </button>
          {{#if this.mostrarClave}}
            <div class="preuni-spoiler-content">
              <div class="preuni-spoiler-clave">{{this.clave}}</div>
            </div>
          {{/if}}
        {{else}}
          <a href="/login" class="preuni-spoiler-btn" style="text-decoration:none;color:inherit;justify-content:flex-start;gap:8px" {{on "click" this.clickLoginClave}}>
            <span>🔒</span>
            Inicia sesión para ver la clave
          </a>
        {{/if}}
        {{#if this.hayRespuestas}}
          <button type="button" class="preuni-spoiler-btn preuni-hilo-btn" {{on "click" this.toggleHilo}}>
            <span>{{if this.preuniHilo.abierto "▴" "▾"}}</span>
            {{if this.preuniHilo.abierto "Ocultar soluciones y comentarios" "Ver soluciones y comentarios"}}
          </button>
        {{/if}}
      </div>
    {{/if}}
    {{#if this.esSolucion}}
      <span class="preuni-solucion-badge">✓ Solución</span>
      {{#if this.esUniversitario}}
        <span class="preuni-universitario-badge">Universitario ✓</span>
      {{/if}}
      {{#if this.esEgresado}}
        <span class="preuni-egresado-badge">Egresado ✓</span>
      {{/if}}
      {{#if this.esModerador}}
        <span class="preuni-moderador-badge">Moderador ✓</span>
      {{/if}}
    {{/if}}
  </template>
}
