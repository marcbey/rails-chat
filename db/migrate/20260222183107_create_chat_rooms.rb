class CreateChatRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_rooms, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :chat_rooms, :name, unique: true
    add_index :chat_rooms, :slug, unique: true
  end
end
