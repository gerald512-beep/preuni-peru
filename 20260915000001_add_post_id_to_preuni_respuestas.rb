# frozen_string_literal: true

class AddPostIdToPreuniRespuestas < ActiveRecord::Migration[7.0]
  def up
    add_column :preuni_respuestas, :post_id, :bigint

    execute <<~SQL
      UPDATE preuni_respuestas pr
      SET post_id = (
        SELECT p.id FROM posts p
        WHERE p.topic_id = pr.topic_id AND p.post_number = 1
        LIMIT 1
      )
      WHERE pr.post_id IS NULL
    SQL

    change_column_null :preuni_respuestas, :post_id, false

    remove_index :preuni_respuestas, [:topic_id, :user_id]
    add_index :preuni_respuestas, [:post_id, :user_id], unique: true
    add_index :preuni_respuestas, :post_id
  end

  def down
    remove_index :preuni_respuestas, [:post_id, :user_id]
    remove_index :preuni_respuestas, :post_id
    add_index :preuni_respuestas, [:topic_id, :user_id], unique: true
    remove_column :preuni_respuestas, :post_id
  end
end
