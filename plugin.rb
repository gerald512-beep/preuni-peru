# frozen_string_literal: true

# name: preuni-question-widget
# about: Interactive MCQ widget for PreUni Perú exam questions
# version: 0.1.0
# authors: PreUni Perú

PREUNI_FIELDS = %w[
  preuni_clave
  preuni_convocatoria
  preuni_numero
  preuni_universidad
  preuni_tema
  preuni_tipo_origen
].freeze

PREUNI_FIELDS.each { |f| register_editable_topic_custom_field(f, staff_only: true) }

after_initialize do
  require_dependency 'topic'

  PREUNI_FIELDS.each { |f| Topic.register_custom_field_type(f, :string) }

  register_post_custom_field_type("preuni_post_type", :string)
  add_permitted_post_create_param(:preuni_post_type)

  add_to_serializer(:topic_view, :preuni_fields) do
    t = object.topic
    t.custom_fields.slice(*PREUNI_FIELDS.map { |f| f }).transform_keys { |k| k.sub('preuni_', '').to_sym }
  end

  on(:post_created) do |post, opts, user|
    tipo = opts[:preuni_post_type]
    if tipo.present? && %w[solucion comentario].include?(tipo)
      post.custom_fields["preuni_post_type"] = tipo
      post.save_custom_fields(true)
    end
  end

  add_to_serializer(:post, :preuni_post_type) do
    object.custom_fields["preuni_post_type"]
  end

  load File.expand_path('../app/models/preuni_respuesta.rb', __FILE__)
  load File.expand_path('../app/controllers/preuni_respuestas_controller.rb', __FILE__)

  Discourse::Application.routes.append do
    post '/preuni/responder'        => 'preuni_respuestas#create'
    get  '/preuni/distribucion/:id' => 'preuni_respuestas#distribucion'
  end
end
