# frozen_string_literal: true

class CreatePreuniRespuestas < ActiveRecord::Migration[7.0]
  def change
    create_table :preuni_respuestas do |t|
      t.bigint  :topic_id,         null: false
      t.bigint  :user_id,          null: false
      t.string  :respuesta,        null: false, limit: 1
      t.integer :tiempo_segundos
      t.timestamps null: false
    end

    add_index :preuni_respuestas, [:topic_id, :user_id], unique: true
    add_index :preuni_respuestas, :topic_id
  end
end
