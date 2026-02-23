class ChatRoom < ApplicationRecord
  include ActionView::RecordIdentifier

  has_many :chat_messages, dependent: :destroy
  has_many :chat_room_memberships, dependent: :destroy
  has_many :users, through: :chat_room_memberships

  before_validation :assign_slug

  validates :name, presence: true, length: { in: 3..80 }, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  after_create_commit :broadcast_new_room

  def to_param
    slug
  end

  def messages_dom_id
    "#{dom_id(self)}_messages"
  end

  def membership_for(user)
    chat_room_memberships.find_or_create_by!(user: user)
  end

  private

  def assign_slug
    return if slug.present? && will_save_change_to_slug?
    return if name.blank?

    candidate = name.parameterize
    candidate = "room" if candidate.blank?

    self.slug = unique_slug_for(candidate)
  end

  def unique_slug_for(base)
    suffix = 0

    loop do
      value = suffix.zero? ? base : "#{base}-#{suffix}"
      return value unless self.class.where.not(id: id).exists?(slug: value)

      suffix += 1
    end
  end

  def broadcast_new_room
    broadcast_prepend_later_to(
      "chat_rooms",
      target: "chat_rooms",
      partial: "chat_rooms/chat_room",
      locals: { chat_room: self }
    )
  end
end
