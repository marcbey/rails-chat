class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :chat_messages, dependent: :restrict_with_exception
  has_many :chat_room_memberships, dependent: :destroy
  has_many :chat_rooms, through: :chat_room_memberships

  normalizes :username, with: ->(value) { value.to_s.strip.downcase }

  validates :username,
    presence: true,
    uniqueness: { case_sensitive: false },
    length: { in: 3..30 },
    format: { with: /\A[a-z0-9_]+\z/, message: "only allows lowercase letters, numbers, and _" }
  validates :bot_character, length: { maximum: 2000 }
end
