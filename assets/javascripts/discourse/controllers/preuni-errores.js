import Controller from "@ember/controller";

// `pregunta` = post id of the question the student came from (the 📋 button);
// the page highlights that row.
export default class PreuniErroresController extends Controller {
  queryParams = ["pregunta"];
  pregunta = null;
}
