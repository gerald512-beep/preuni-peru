import PreuniErrorLog from "../components/preuni-error-log";

export default <template>
  <div class="preuni-errores-page">
    <PreuniErrorLog @resaltar={{@controller.pregunta}} />
  </div>
</template>
