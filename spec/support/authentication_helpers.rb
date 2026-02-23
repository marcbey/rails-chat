module AuthenticationHelpers
  def sign_in_as(user, password: "password123!")
    post session_path, params: { username: user.username, password: password }
  end
end
