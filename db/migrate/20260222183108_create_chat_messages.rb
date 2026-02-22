class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages, id: :uuid do |t|
      t.references :chat_room, type: :uuid, null: false, foreign_key: true
      t.string :author_name, null: false
      t.text :body, null: false

      t.timestamps
    end
    add_index :chat_messages, %i[chat_room_id created_at]
  end
end
