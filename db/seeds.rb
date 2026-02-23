# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  username = ENV.fetch("SEED_USERNAME", "demo")
  password = ENV.fetch("SEED_PASSWORD", "password123!")

  user = User.find_or_initialize_by(username: username)
  if user.new_record?
    user.password = password
    user.password_confirmation = password
    user.bot_character = "Du bist ein hilfreicher und freundlicher Chat-Bot."
    user.save!
  end
end
