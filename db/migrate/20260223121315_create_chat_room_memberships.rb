class CreateChatRoomMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_room_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chat_room, type: :uuid, null: false, foreign_key: true
      t.boolean :bot_enabled, null: false, default: false

      t.timestamps
    end

    add_index :chat_room_memberships, %i[user_id chat_room_id], unique: true
  end
end
