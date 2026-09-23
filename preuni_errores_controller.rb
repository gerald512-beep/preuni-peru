# frozen_string_literal: true

# "Registro de errores": the signed-in student's own answers, with the private
# note they wrote about each. Everything is scoped to current_user and keyed
# by post_id (a reading cluster's linked questions are separate posts, so each
# one logs, scores and links on its own).
class PreuniErroresController < ApplicationController
  # `pagina` only serves the Ember app shell; the client route sends signed-out
  # visitors to the login page itself.
  requires_login except: [:pagina]
  skip_before_action :verify_authenticity_token, if: :is_api?

  MAX_ITEMS = 500
  UMBRAL_DIFICULTAD = 50 # same threshold as the difficulty badge

  # puntaje = correctas - valor * incorrectas. Only universities whose rule is
  # actually defined (roadmap: UNMSM deducts 0.25 per wrong answer) get a
  # score; the others just show counts. The client does the arithmetic on the
  # rows currently in view, so it needs the values.
  PENALIZACION = { 'UNMSM' => 0.25 }.freeze

  TOPIC_FIELDS = %w[preuni_clave preuni_numero preuni_universidad preuni_convocatoria preuni_tema].freeze

  def pagina
    respond_to { |format| format.html { render "default/empty" } }
  end

  # Params: resultado (incorrectas|correctas|todas, default incorrectas),
  # tema, dias (only answers from the last N days; 0/absent = all time).
  def index
    resultado = %w[incorrectas correctas todas].include?(params[:resultado]) ? params[:resultado] : 'incorrectas'
    tema = params[:tema].presence
    dias = params[:dias].to_i
    desde = dias > 0 ? dias.days.ago : nil

    filas = filas_del_usuario(desde)
    filas = filas.select do |f|
      (resultado == 'todas' || (resultado == 'incorrectas' ? f[:correcto] == false : f[:correcto] == true)) &&
        (tema.nil? || f[:tema] == tema)
    end
    truncado = filas.size > MAX_ITEMS
    filas = filas.first(MAX_ITEMS)

    post_ids = filas.map { |f| f[:post].id }
    notas = PreuniNotaError.where(user_id: current_user.id, post_id: post_ids).pluck(:post_id, :nota).to_h
    dificultades = dificultades_para(filas)

    items = filas.map do |f|
      post = f[:post]
      topic = f[:topic]
      {
        post_id: post.id,
        topic_id: topic.id,
        url: "#{Discourse.base_path}/t/#{topic.slug}/#{topic.id}/#{post.post_number}",
        titulo: topic.title,
        numero: f[:numero],
        universidad: f[:universidad],
        convocatoria: f[:convocatoria],
        tema: f[:tema],
        respuesta: f[:respuesta].respuesta,
        clave: f[:clave],
        correcto: f[:correcto],
        tiempo_segundos: f[:respuesta].tiempo_segundos,
        respondida_en: f[:respuesta].created_at.iso8601,
        dificultad: dificultades[post.id],
        nota: notas[post.id] || '',
      }
    end

    render json: { items: items, truncado: truncado, penalizaciones: PENALIZACION, racha: racha_actual }
  end

  def update_nota
    post_id = params.require(:post_id).to_i
    nota = params[:nota].to_s.strip

    unless PreuniRespuesta.exists?(user_id: current_user.id, post_id: post_id)
      return render json: { error: 'Solo puedes anotar preguntas que ya respondiste' }, status: :unprocessable_entity
    end

    if nota.empty?
      PreuniNotaError.where(user_id: current_user.id, post_id: post_id).delete_all
      return render json: { ok: true, nota: '' }
    end

    registro = PreuniNotaError.find_or_initialize_by(user_id: current_user.id, post_id: post_id)
    registro.nota = nota
    if registro.save
      render json: { ok: true, nota: registro.nota }
    else
      render json: { error: registro.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  private

  # Every answer the user has given to a question that still exists and has a
  # key, newest first, with the metadata the log needs. correcto is computed
  # here (the key never reaches the client before the user has answered, and
  # they have by definition).
  def filas_del_usuario(desde = nil)
    scope = PreuniRespuesta.where(user_id: current_user.id)
    scope = scope.where('created_at >= ?', desde) if desde
    respuestas = scope.order(created_at: :desc, id: :desc).to_a
    posts = Post.where(id: respuestas.map(&:post_id)).includes(:topic).index_by(&:id)
    respuestas = respuestas.select { |r| posts[r.post_id]&.topic }

    post_ids = respuestas.map(&:post_id)
    topic_ids = respuestas.map { |r| posts[r.post_id].topic.id }.uniq

    post_claves = {}
    post_numeros = {}
    PostCustomField.where(post_id: post_ids, name: %w[preuni_clave preuni_numero])
                   .pluck(:post_id, :name, :value).each do |pid, name, value|
      (name == 'preuni_clave' ? post_claves : post_numeros)[pid] = value
    end

    topic_meta = Hash.new { |h, k| h[k] = {} }
    TopicCustomField.where(topic_id: topic_ids, name: TOPIC_FIELDS)
                    .pluck(:topic_id, :name, :value).each { |tid, name, value| topic_meta[tid][name] = value }

    respuestas.filter_map do |r|
      post = posts[r.post_id]
      topic = post.topic
      meta = topic_meta[topic.id]
      # A linked question keeps its key/number on its own post; a root
      # question keeps them on the topic.
      clave = post_claves[r.post_id].presence || meta['preuni_clave']
      next if clave.blank?

      {
        respuesta: r,
        post: post,
        topic: topic,
        clave: clave,
        correcto: r.respuesta == clave,
        numero: post_numeros[r.post_id].presence || meta['preuni_numero'],
        universidad: meta['preuni_universidad'],
        convocatoria: meta['preuni_convocatoria'],
        tema: meta['preuni_tema'].presence || topic.category&.name,
      }
    end
  end

  # Consecutive days (ending today, or yesterday if nothing answered yet today)
  # with at least one answer. Counted over ALL the user's answers, not just the
  # period being viewed.
  def racha_actual
    dias = PreuniRespuesta.where(user_id: current_user.id).pluck(:created_at).map(&:to_date).to_set
    dia = Date.current
    dia -= 1 unless dias.include?(dia)
    racha = 0
    while dias.include?(dia)
      racha += 1
      dia -= 1
    end
    racha
  end

  # Same bands as the difficulty badge, per question post, hidden until enough
  # people have answered.
  def dificultades_para(filas)
    return {} if filas.empty?

    ids = filas.map { |f| f[:post].id }
    counts = PreuniRespuesta.where(post_id: ids).group(:post_id, :respuesta).count

    filas.each_with_object({}) do |f, out|
      pid = f[:post].id
      total = PreuniRespuesta::VALID.sum { |l| counts[[pid, l]] || 0 }
      next if total < UMBRAL_DIFICULTAD

      pct = ((counts[[pid, f[:clave]]] || 0).to_f / total * 100).round(1)
      out[pid] = pct > 65 ? 'facil' : (pct < 20 ? 'dificil' : 'medio')
    end
  end
end
