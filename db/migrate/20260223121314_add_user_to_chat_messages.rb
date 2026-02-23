require "bcrypt"
require "securerandom"

class AddUserToChatMessages < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  class MigrationChatMessage < ApplicationRecord
    self.table_name = "chat_messages"
  end

  def up
    add_reference :chat_messages, :user, foreign_key: true
    MigrationChatMessage.reset_column_information
    MigrationUser.reset_column_information

    if MigrationChatMessage.exists?
      legacy_user = MigrationUser.find_or_create_by!(username: "legacy_user") do |user|
        user.password_digest = BCrypt::Password.create(SecureRandom.base58(32))
        user.bot_character = ""
      end

      MigrationChatMessage.where(user_id: nil).update_all(user_id: legacy_user.id)
    end

    change_column_null :chat_messages, :user_id, false
  end

  def down
    remove_reference :chat_messages, :user, foreign_key: true
  end
end
