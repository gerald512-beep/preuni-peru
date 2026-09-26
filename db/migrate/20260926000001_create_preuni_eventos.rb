class CreatePreuniEventos < ActiveRecord::Migration[7.0]
  def change
    create_table :preuni_eventos do |t|
      t.string   :evento,       null: false
      t.bigint   :user_id
      t.string   :visitante_id, null: false
      t.bigint   :topic_id
      t.bigint   :post_id
      t.jsonb    :datos,        null: false, default: {}
      t.datetime :created_at,   null: false
    end
    add_index :preuni_eventos, [:evento, :created_at]
    add_index :preuni_eventos, :user_id
    add_index :preuni_eventos, :visitante_id
  end
end
