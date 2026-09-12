import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";

export default class PreuniClave extends Component {
  @tracked mostrarClave = false;

  get post() { return this.args.outletArgs?.post; }
  get clave() { return this.post?.topic?.preuni_fields?.clave; }
  get esPreuni() { return this.post?.post_number === 1 && !!this.clave; }

  @action
  toggleClave() {
    this.mostrarClave = !this.mostrarClave;
  }

  <template>
    {{#if this.esPreuni}}
      <div class="preuni-spoiler-wrap">
        <button type="button" class="preuni-spoiler-btn" {{on "click" this.toggleClave}}>
          <span>{{if this.mostrarClave "▴" "▾"}}</span>
          Mostrar clave
        </button>
        {{#if this.mostrarClave}}
          <div class="preuni-spoiler-content">
            <div class="preuni-spoiler-clave">{{this.clave}}</div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
