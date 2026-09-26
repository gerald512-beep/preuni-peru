# frozen_string_literal: true

class PreuniPreguntaIndice < ActiveRecord::Base
  self.table_name = 'preuni_preguntas_indice'

  belongs_to :topic
  belongs_to :post

  validates :post_id, uniqueness: true
  validates :universidad, :anio, :tema, presence: true

  # Root question of a topic (post_number == 1). Only indexes topics that are
  # actually a preuni question (preuni_clave present) -- an ordinary
  # discussion topic has none of these fields and is silently skipped.
  def self.sync_from_topic!(topic)
    f = topic.custom_fields
    return unless f['preuni_clave'].present?

    root_post_id = topic.first_post&.id || Post.where(topic_id: topic.id, post_number: 1).pick(:id)
    return unless root_post_id

    upsert!(
      post_id: root_post_id,
      topic_id: topic.id,
      universidad: f['preuni_universidad'],
      anio: f['preuni_anio'],
      convocatoria: f['preuni_convocatoria'],
      modalidad: f['preuni_modalidad'],
      tipo_area: f['preuni_tipo_area'],
      tema: f['preuni_tema'],
    )
  end

  # A "pregunta_adicional" reply inside a reading-passage cluster -- it has
  # its own preuni_clave/preuni_numero but shares the parent topic's
  # classification (universidad/anio/convocatoria/modalidad/tipo_area/tema).
  def self.sync_from_post!(post)
    pf = post.custom_fields
    return unless pf['preuni_post_type'] == 'pregunta_adicional' && pf['preuni_clave'].present?

    tf = post.topic.custom_fields
    upsert!(
      post_id: post.id,
      topic_id: post.topic_id,
      universidad: tf['preuni_universidad'],
      anio: tf['preuni_anio'],
      convocatoria: tf['preuni_convocatoria'],
      modalidad: tf['preuni_modalidad'],
      tipo_area: tf['preuni_tipo_area'],
      tema: tf['preuni_tema'],
    )
  end

  def self.upsert!(attrs)
    return unless attrs[:universidad].present? && attrs[:tema].present?
    anio = attrs[:anio].presence&.to_i
    return unless anio.present?

    row = find_or_initialize_by(post_id: attrs[:post_id])
    row.assign_attributes(attrs.merge(anio: anio))
    row.save!
    row
  end
end
