# frozen_string_literal: true

class PreuniRespuesta < ActiveRecord::Base
  self.table_name = 'preuni_respuestas'

  belongs_to :topic
  belongs_to :post
  belongs_to :user

  VALID = %w[A B C D E].freeze
  validates :respuesta, inclusion: { in: VALID }
  validates :post_id, uniqueness: { scope: :user_id }
end
