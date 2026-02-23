class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    email_address = params[:email_address].to_s.strip.downcase
    user = User.find_by(email_address: email_address)
    PasswordsMailer.reset(user).deliver_now if user

    redirect_to new_session_path, notice: "If an account exists for that email address, password reset instructions have been sent."
  end

  def edit
  end

  def update
    if @user.update(password_params)
      @user.sessions.delete_all
      redirect_to new_session_path, notice: "Password updated. Please sign in."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
  end
end
