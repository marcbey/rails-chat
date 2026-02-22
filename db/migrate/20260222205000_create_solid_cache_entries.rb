class CreateSolidCacheEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536_870_912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false
    end

    add_index :solid_cache_entries, :byte_size, if_not_exists: true
    add_index :solid_cache_entries, :key_hash, unique: true, if_not_exists: true
    add_index :solid_cache_entries, %i[key_hash byte_size], if_not_exists: true
  end
end
