# frozen_string_literal: true

# A student's private note on one question they answered ("what went wrong").
# Keyed by post_id, not topic_id, so each question of a reading cluster keeps
# its own note.
class CreatePreuniNotasError < ActiveRecord::Migration[7.0]
  def change
    create_table :preuni_notas_error do |t|
      t.bigint :user_id, null: false
      t.bigint :post_id, null: false
      t.text   :nota,    null: false
      t.timestamps
    end

    add_index :preuni_notas_error, [:user_id, :post_id], unique: true
    add_index :preuni_notas_error, :post_id
  end
end
