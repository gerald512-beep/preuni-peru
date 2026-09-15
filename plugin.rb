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

  # A "pregunta_adicional" is a reply that is itself a full question (with its
  # own clave/numero) -- used for reading-passage clusters where the root post
  # holds the shared text + question 1, and each further linked question is a
  # reply rather than a separate topic. Same storage shape as the topic-level
  # PREUNI_FIELDS, just scoped to the post instead.
  register_post_custom_field_type("preuni_clave", :string)
  register_post_custom_field_type("preuni_numero", :string)
  add_permitted_post_create_param(:preuni_clave)
  add_permitted_post_create_param(:preuni_numero)

  add_to_serializer(:topic_view, :preuni_fields) do
    t = object.topic
    base = t.custom_fields.slice(*PREUNI_FIELDS).transform_keys { |k| k.sub('preuni_', '').to_sym }

    if base[:clave].present?
      counts = PreuniRespuesta.where(topic_id: t.id).group(:respuesta).count
      total  = counts.values.sum
      if total >= 50
        n_correct = counts[base[:clave]] || 0
        pct = (n_correct.to_f / total * 100).round(1)
        base[:total_intentos] = total
        base[:pct_correcto]   = pct
        base[:dificultad]     = pct > 65 ? "facil" : (pct < 20 ? "dificil" : "medio")
      end
    end

    base
  end

  on(:post_created) do |post, opts, user|
    tipo = opts[:preuni_post_type]
    if tipo.present? && %w[solucion comentario pregunta_adicional].include?(tipo)
      # Guard: none of these can be root posts (post_number == 1) -- a root
      # post is always the plain "pregunta" type, implicit, no tipo needed.
      if post.post_number > 1
        post.custom_fields["preuni_post_type"] = tipo
        if tipo == "pregunta_adicional"
          post.custom_fields["preuni_clave"] = opts[:preuni_clave] if opts[:preuni_clave].present?
          post.custom_fields["preuni_numero"] = opts[:preuni_numero] if opts[:preuni_numero].present?
        end
        post.save_custom_fields(true)
      end
    end
  end

  add_to_serializer(:post, :preuni_post_type) do
    object.custom_fields["preuni_post_type"]
  end

  add_to_serializer(:post, :preuni_clave) do
    object.custom_fields["preuni_clave"]
  end

  add_to_serializer(:post, :preuni_numero) do
    object.custom_fields["preuni_numero"]
  end

  add_to_serializer(:post, :preuni_is_universitario) do
    object.user&.groups&.where(name: 'universitario')&.any? || false
  end

  add_to_serializer(:post, :preuni_is_egresado) do
    object.user&.groups&.where(name: 'egresado')&.any? || false
  end

  add_to_serializer(:post, :preuni_is_moderador) do
    object.user&.groups&.where(name: 'moderador')&.any? || false
  end

  load File.expand_path('../app/models/preuni_respuesta.rb', __FILE__)
  load File.expand_path('../app/controllers/preuni_respuestas_controller.rb', __FILE__)

  PreuniRespuestasController.class_eval do
    def difficulties
      topic_ids = TopicCustomField
        .where(name: 'preuni_clave')
        .where.not(value: [nil, ''])
        .joins("INNER JOIN topics ON topics.id = topic_custom_fields.topic_id AND topics.deleted_at IS NULL")
        .pluck(:topic_id)

      if topic_ids.empty?
        return render json: { difficulties: {} }
      end

      counts = PreuniRespuesta.where(topic_id: topic_ids).group(:topic_id, :respuesta).count
      claves = TopicCustomField.where(topic_id: topic_ids, name: 'preuni_clave').pluck(:topic_id, :value).to_h

      result = {}
      topic_ids.each do |tid|
        clave = claves[tid]
        next unless clave.present?

        total = 0
        correct = 0
        counts.each do |(t, resp), cnt|
          next unless t == tid
          total += cnt
          correct += cnt if resp == clave
        end

        if total >= 50
          pct = (correct.to_f / total * 100).round(1)
          dif = pct > 65 ? "facil" : (pct < 20 ? "dificil" : "medio")
          result[tid] = { dificultad: dif, total_intentos: total }
        else
          result[tid] = { dificultad: "por_definir", total_intentos: total }
        end
      end

      render json: { difficulties: result }
    end
  end

  Discourse::Application.routes.append do
    post '/preuni/responder'        => 'preuni_respuestas#create'
    get  '/preuni/distribucion/:id' => 'preuni_respuestas#distribucion'
    get  '/preuni/difficulties'     => 'preuni_respuestas#difficulties'
  end
end
