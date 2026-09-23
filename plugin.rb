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

register_svg_icon "clipboard-list"

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

  # Same difficulty computation as the topic-level one above, scoped to a
  # single pregunta_adicional post -- linked questions get their own
  # difficulty badge instead of silently sharing the root question's.
  add_to_serializer(:post, :preuni_dificultad) do
    next nil unless object.custom_fields["preuni_post_type"] == "pregunta_adicional"
    clave = object.custom_fields["preuni_clave"]
    next nil unless clave.present?
    counts = PreuniRespuesta.where(post_id: object.id).group(:respuesta).count
    total  = counts.values.sum
    next nil if total < 50
    n_correct = counts[clave] || 0
    pct = (n_correct.to_f / total * 100).round(1)
    pct > 65 ? "facil" : (pct < 20 ? "dificil" : "medio")
  end

  add_to_serializer(:post, :preuni_total_intentos) do
    next nil unless object.custom_fields["preuni_post_type"] == "pregunta_adicional"
    n = PreuniRespuesta.where(post_id: object.id).count
    n >= 50 ? n : nil
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

  # Custom report reasons, in addition to Discourse's built-in spam/off-topic/
  # inappropriate: a copyright claim, a wrong or misleading solution, and a
  # catch-all. Seeded once per flag name on boot; an admin's later edits from
  # Admin > Flags (description, enabled, etc.) are never overwritten, since
  # this only creates a flag the first time its name doesn't exist yet.
  PREUNI_FLAGS = [
    {
      name: 'Derechos de autor',
      description: 'La pregunta, la solución o alguna imagen reproduce material con derechos de autor sin permiso. Indica la fuente si la conoces.',
    },
    {
      name: 'Solución incorrecta o engañosa',
      description: 'La clave, la explicación o alguna imagen de la solución está equivocada, incompleta o puede llevar a confusión. Indica qué crees que está mal.',
    },
    {
      name: 'Otro motivo',
      description: 'Cualquier otro problema con esta pregunta o publicación que no encaje en las demás opciones.',
    },
  ].freeze

  PREUNI_FLAGS.each do |attrs|
    Flag.find_or_create_by!(name: attrs[:name]) do |f|
      f.description = attrs[:description]
      f.require_message = true
      f.enabled = true
      f.applies_to = %w[Post Topic]
      f.auto_action_type = false
      f.notify_type = true
    end
  end

  load File.expand_path('../app/models/preuni_respuesta.rb', __FILE__)
  load File.expand_path('../app/controllers/preuni_respuestas_controller.rb', __FILE__)
  load File.expand_path('../app/models/preuni_nota_error.rb', __FILE__)
  load File.expand_path('../app/controllers/preuni_errores_controller.rb', __FILE__)

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

      # A reading-passage cluster topic has more than one question in it (the
      # root plus its linked replies) -- the root's own difficulty alone would
      # be misleading shown as "the" difficulty for the whole topic, so these
      # get a distinct marker instead of a computed facil/medio/dificil value.
      # The real per-question difficulty still lives on each question's own
      # pill inside the topic; this is only about the one-row-per-topic list.
      cluster_topic_ids = PostCustomField
        .where(name: 'preuni_post_type', value: 'pregunta_adicional')
        .joins("INNER JOIN posts ON posts.id = post_custom_fields.post_id AND posts.deleted_at IS NULL")
        .where(posts: { topic_id: topic_ids })
        .distinct
        .pluck('posts.topic_id')
        .to_set

      linked_counts = Hash.new(0)
      if cluster_topic_ids.any?
        linked_counts = PostCustomField
          .where(name: 'preuni_post_type', value: 'pregunta_adicional')
          .joins("INNER JOIN posts ON posts.id = post_custom_fields.post_id AND posts.deleted_at IS NULL")
          .where(posts: { topic_id: cluster_topic_ids.to_a })
          .group('posts.topic_id')
          .count
      end

      result = {}
      topic_ids.each do |tid|
        if cluster_topic_ids.include?(tid)
          result[tid] = { dificultad: "lectura", num_preguntas: (linked_counts[tid] || 0) + 1 }
          next
        end

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

    # Tags created through the normal HTTP tag APIs (POST /admin/tags, or
    # array-of-strings in a topic PUT) get their special characters stripped
    # by Discourse's tag-name sanitizer -- "N°99" silently becomes "n99".
    # Tag.find_or_create_by! at the model layer skips that sanitizer, so this
    # is the only reliable way to create an exact "N°X" tag name from the
    # composer's server-side code.
    def ensure_tag
      raise Discourse::InvalidAccess unless current_user&.staff?
      name = params.require(:name)
      Tag.find_or_create_by!(name: name)
      render json: { ok: true, name: name }
    end

    # The question number lives only as an attribute (preuni_numero = "35"),
    # not as an N°35 / n35 tag, so duplicate detection looks the attribute up
    # directly: topic-level for a normal question, post-level for a linked
    # question inside a reading cluster. Optional filters narrow by
    # universidad and convocatoria ("2026-II").
    def find_by_numero
      raise Discourse::InvalidAccess unless current_user&.staff?
      numero = params.require(:numero).to_s

      topic_ids = TopicCustomField.where(name: 'preuni_numero', value: numero).pluck(:topic_id)
      linked_topic_ids = PostCustomField
        .where(name: 'preuni_numero', value: numero)
        .joins("INNER JOIN posts ON posts.id = post_custom_fields.post_id AND posts.deleted_at IS NULL")
        .pluck('posts.topic_id')

      topics = Topic.where(id: (topic_ids + linked_topic_ids).uniq, deleted_at: nil).select do |t|
        f = t.custom_fields
        (params[:universidad].blank? || f['preuni_universidad'] == params[:universidad].to_s) &&
          (params[:convocatoria].blank? || f['preuni_convocatoria'] == params[:convocatoria].to_s)
      end

      render json: {
        topics: topics.map { |t| { id: t.id, slug: t.slug, title: t.title, category_id: t.category_id } }
      }
    end
  end

  Discourse::Application.routes.append do
    post '/preuni/responder'        => 'preuni_respuestas#create'
    get  '/preuni/distribucion/:id' => 'preuni_respuestas#distribucion'
    get  '/preuni/difficulties'     => 'preuni_respuestas#difficulties'
    post '/preuni/ensure-tag'       => 'preuni_respuestas#ensure_tag'
    get  '/preuni/find'             => 'preuni_respuestas#find_by_numero'
    get  '/errores'                 => 'preuni_errores#pagina'
    get  '/preuni/errores'          => 'preuni_errores#index'
    put  '/preuni/errores/:post_id/nota' => 'preuni_errores#update_nota'
  end
end
