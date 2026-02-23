class AccountsController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(account_params)
      redirect_to edit_account_path, notice: "Account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    permitted = params.require(:user).permit(:username, :email_address, :bot_character, :password, :password_confirmation)
    return permitted if permitted[:password].present?

    permitted.except(:password, :password_confirmation)
  end
end
