import Component from "@glimmer/component";
import PreuniWidget from "../../components/preuni-widget";

export default class PreuniConnector extends Component {
  get fields() { return this.args.outletArgs.model?.preuni_fields; }
  get esPreuni() { return !!this.fields?.clave; }

  <template>
    <PreuniWidget @topic={{@outletArgs.model}} />
  </template>
}
