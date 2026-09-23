# frozen_string_literal: true

class PreuniNotaError < ActiveRecord::Base
  self.table_name = 'preuni_notas_error'

  MAX_LENGTH = 2000

  belongs_to :user
  belongs_to :post

  validates :nota, presence: true, length: { maximum: MAX_LENGTH }
  validates :post_id, uniqueness: { scope: :user_id }
end
