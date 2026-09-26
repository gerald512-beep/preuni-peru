# frozen_string_literal: true

# Denormalized, indexed copy of a question's classification fields (the 6
# single-value facets of the 7-facet filter -- Sub Tema stays as Discourse
# tags, not a column here). One row per question: a topic's root post OR a
# reading-cluster's "pregunta_adicional" reply, keyed by post_id since that's
# the one identifier both forms share. Exists purely to make multi-select
# faceted search fast (WHERE col IN (...) per dimension) -- the custom
# fields on the topic/post remain the source of truth; this table is a
# read-optimized cache kept in sync by PreuniPreguntaIndice.sync_from_topic!/
# sync_from_post! (called from plugin.rb hooks and from backfill scripts).
class CreatePreuniPreguntasIndice < ActiveRecord::Migration[7.0]
  def change
    create_table :preuni_preguntas_indice do |t|
      t.bigint  :post_id,       null: false
      t.bigint  :topic_id,      null: false
      t.string  :universidad,   null: false
      t.integer :anio,          null: false
      t.string  :convocatoria
      t.string  :modalidad
      t.string  :tipo_area
      t.string  :tema,          null: false
      t.timestamps
    end

    add_index :preuni_preguntas_indice, :post_id, unique: true
    add_index :preuni_preguntas_indice, :topic_id
    add_index :preuni_preguntas_indice, :universidad
    add_index :preuni_preguntas_indice, :anio
    add_index :preuni_preguntas_indice, :convocatoria
    add_index :preuni_preguntas_indice, :modalidad
    add_index :preuni_preguntas_indice, :tipo_area
    add_index :preuni_preguntas_indice, :tema
  end
end
