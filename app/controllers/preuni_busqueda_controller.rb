# frozen_string_literal: true

# Public faceted search over the question bank -- GET /preuni/buscar with any
# of the 7 filter dimensions as array params (e.g. universidad[]=UNI&anio[]=2019),
# each multi-select (OR'd within a dimension) and ANDed together across
# dimensions. Backs the filter bar that replaces Discourse's native
# categorías>/etiquetas> dropdowns on discovery pages (Phase 5). No login
# required -- this is public question-bank browsing, same as the difficulty
# chips on the topic list.
class PreuniBusquedaController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :is_api?

  MAX_ITEMS = 100
  UMBRAL_DIFICULTAD = 50

  FACET_COLUMNS = %w[universidad anio convocatoria modalidad tipo_area tema].freeze

  # Slugified Modalidad/Tipo-Área values (see question-composer-prototype.html
  # TIPO_AREA and the Modalidad <select>) -- these are topic tags too, but a
  # different facet from Sub Tema, so they're excluded from the subtema list
  # returned per item.
  NON_SUBTEMA_TAGS = %w[
    ordinario traslado escolar simulacro cepre
    area-a area-b area-c area-d area-e
    aptitud-y-humanidades matematica fisica-quimica
  ].freeze

  def index
    scope = PreuniPreguntaIndice.all

    FACET_COLUMNS.each do |col|
      values = array_param(col)
      next if values.empty?
      scope = scope.where(col => values)
    end

    subtemas = array_param(:subtema)
    if subtemas.any?
      topic_ids = TopicTag.joins(:tag).where(tags: { name: subtemas }).select(:topic_id)
      scope = scope.where(topic_id: topic_ids)
    end

    total = scope.count
    filas = scope.order(id: :desc).limit(MAX_ITEMS).to_a
    truncado = total > filas.size

    post_ids = filas.map(&:post_id)
    topic_ids = filas.map(&:topic_id).uniq
    posts = Post.where(id: post_ids).includes(:topic).index_by(&:id)

    dificultades = dificultades_para(filas)
    numeros = numeros_para(filas)
    subtemas_por_topic = subtemas_por_topic_para(topic_ids)

    items = filas.filter_map do |f|
      post = posts[f.post_id]
      next unless post&.topic

      {
        post_id: f.post_id,
        topic_id: f.topic_id,
        url: "#{Discourse.base_path}/t/#{post.topic.slug}/#{f.topic_id}/#{post.post_number}",
        titulo: post.topic.title,
        numero: numeros[f.post_id],
        universidad: f.universidad,
        anio: f.anio,
        convocatoria: f.convocatoria,
        modalidad: f.modalidad,
        tipo_area: f.tipo_area,
        tema: f.tema,
        subtemas: subtemas_por_topic[f.topic_id] || [],
        dificultad: dificultades[f.post_id],
      }
    end

    render json: { items: items, total: total, truncado: truncado }
  end

  # Every value each dimension currently takes across the published question
  # bank -- derived live from the index table + tags rather than a hardcoded
  # list, so the filter bar never drifts from what's actually filterable.
  def opciones
    data = FACET_COLUMNS.index_with { |col| PreuniPreguntaIndice.distinct.where.not(col => nil).order(col).pluck(col) }
    data[:subtema] = subtemas_por_topic_para(PreuniPreguntaIndice.distinct.pluck(:topic_id)).values.flatten.uniq.sort
    render json: data
  end

  private

  # `params.permit(name => [])` is the safe way to read a "should be an array
  # of scalars" query param -- a malformed shape like `?universidad[bad]=x`
  # (parsed as a Hash, not an Array) is silently dropped instead of reaching
  # `.where` and blowing up with a 500.
  def array_param(name)
    params.permit(name => []).fetch(name, []).reject(&:blank?)
  end

  # Clave lookup mirrors PreuniRespuestasController#clave_for / PreuniErroresController#filas_del_usuario:
  # a linked question's clave lives on its own post, a root question's on the topic.
  def dificultades_para(filas)
    return {} if filas.empty?

    post_ids = filas.map(&:post_id)
    topic_ids = filas.map(&:topic_id).uniq

    post_claves = PostCustomField.where(post_id: post_ids, name: 'preuni_clave').pluck(:post_id, :value).to_h
    topic_claves = TopicCustomField.where(topic_id: topic_ids, name: 'preuni_clave').pluck(:topic_id, :value).to_h

    counts = PreuniRespuesta.where(post_id: post_ids).group(:post_id, :respuesta).count

    filas.each_with_object({}) do |f, out|
      clave = post_claves[f.post_id].presence || topic_claves[f.topic_id]
      next unless clave.present?

      total = PreuniRespuesta::VALID.sum { |l| counts[[f.post_id, l]] || 0 }
      next if total < UMBRAL_DIFICULTAD

      pct = ((counts[[f.post_id, clave]] || 0).to_f / total * 100).round(1)
      out[f.post_id] = pct > 65 ? 'facil' : (pct < 20 ? 'dificil' : 'medio')
    end
  end

  # Same lookup precedence as clave: a linked question's own post carries its
  # own preuni_numero, a root question's lives on the topic. Two questions
  # that share a reading-cluster topic (and so share the topic's title) are
  # otherwise indistinguishable in the results list -- this is what tells
  # them apart (rendered as "N.º X", same convention as /errores).
  def numeros_para(filas)
    return {} if filas.empty?

    post_ids = filas.map(&:post_id)
    topic_ids = filas.map(&:topic_id).uniq

    post_numeros = PostCustomField.where(post_id: post_ids, name: 'preuni_numero').pluck(:post_id, :value).to_h
    topic_numeros = TopicCustomField.where(topic_id: topic_ids, name: 'preuni_numero').pluck(:topic_id, :value).to_h

    filas.each_with_object({}) do |f, out|
      out[f.post_id] = post_numeros[f.post_id].presence || topic_numeros[f.topic_id]
    end
  end

  def subtemas_por_topic_para(topic_ids)
    return {} if topic_ids.empty?

    TopicTag.joins(:tag).where(topic_id: topic_ids)
            .pluck(:topic_id, 'tags.name')
            .each_with_object(Hash.new { |h, k| h[k] = [] }) do |(tid, name), out|
      next if NON_SUBTEMA_TAGS.include?(name) || name =~ /\A\d+\z/

      out[tid] << name
    end
  end
end
