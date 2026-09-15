import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { on } from "@ember/modifier";
import PreuniWidget from "../../components/preuni-widget";

export default class PreuniClave extends Component {
  @service currentUser;
  @tracked mostrarClave = false;

  get post() { return this.args.outletArgs?.post; }
  get clave() { return this.post?.topic?.preuni_fields?.clave; }
  get esPreuni() { return this.post?.post_number === 1 && !!this.clave; }
  get esSolucion() { return this.post?.preuni_post_type === "solucion" && this.post?.post_number > 1; }
  get esPreguntaAdicional() { return this.post?.preuni_post_type === "pregunta_adicional" && this.post?.post_number > 1; }
  get esUniversitario() { return this.post?.preuni_is_universitario === true; }
  get esEgresado()     { return this.post?.preuni_is_egresado     === true; }
  get esModerador()    { return this.post?.preuni_is_moderador    === true; }

  @action
  toggleClave() {
    this.mostrarClave = !this.mostrarClave;
  }

  <template>
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
          <a href="/login" class="preuni-spoiler-btn" style="text-decoration:none;color:inherit;justify-content:flex-start;gap:8px">
            <span>🔒</span>
            Inicia sesión para ver la clave
          </a>
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
    {{#if this.esPreguntaAdicional}}
      <PreuniWidget @post={{this.post}} />
    {{/if}}
  </template>
}
