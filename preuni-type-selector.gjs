import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { on } from "@ember/modifier";
import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";

export default class PreuniTypeSelector extends Component {
  @tracked tipo = "comentario";

  constructor(owner, args) {
    super(owner, args);
    this._syncToModel("comentario");
  }

  get model() {
    return this.args.outletArgs?.model;
  }

  get esPreuni() {
    const m = this.model;
    if (!m || m.creatingTopic) return false;
    return !!m.topic?.preuni_fields?.clave;
  }

  _syncToModel(valor) {
    const m = this.model;
    if (m) m.set("preuni_post_type", valor);
  }

  @action
  setTipo(valor) {
    this.tipo = valor;
    this._syncToModel(valor);
  }

  <template>
    {{#if this.esPreuni}}
      <div class="preuni-type-selector">
        <span class="preuni-type-label">Tipo:</span>
        <button
          type="button"
          class={{if (eq this.tipo "solucion") "preuni-type-btn solucion active" "preuni-type-btn solucion"}}
          {{on "click" (fn this.setTipo "solucion")}}
        >Solución</button>
        <button
          type="button"
          class={{if (eq this.tipo "comentario") "preuni-type-btn comentario active" "preuni-type-btn comentario"}}
          {{on "click" (fn this.setTipo "comentario")}}
        >Comentario</button>
      </div>
    {{/if}}
  </template>
}
