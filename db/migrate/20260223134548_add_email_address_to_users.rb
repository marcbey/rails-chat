class AddEmailAddressToUsers < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    add_column :users, :email_address, :string
    MigrationUser.reset_column_information

    MigrationUser.find_each do |user|
      next if user.email_address.present?

      local_part = user.username.to_s.gsub(/[^a-z0-9_]/i, "").presence || "user#{user.id}"
      user.update_columns(email_address: "#{local_part}+#{user.id}@example.invalid".downcase)
    end

    change_column_null :users, :email_address, false
    add_index :users, :email_address, unique: true
  end

  def down
    remove_index :users, :email_address
    remove_column :users, :email_address
  end
end
