class RemoveAuthorNameFromChatMessages < ActiveRecord::Migration[8.1]
  def change
    remove_column :chat_messages, :author_name, :string
  end
end
