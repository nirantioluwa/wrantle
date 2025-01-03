class RegistrationsController < ApplicationController
  # Allow unauthenticated access to registration
  allow_unauthenticated_access

  # Rate limiting to prevent abuse
  rate_limit to: 10,
    within: 3.minutes,
    only: :create,
    with: -> { redirect_to new_registration_url, alert: "Too many attempts. Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(safe_params)

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Welcome! Your account has been created successfully."
    else
      flash.now[:alert] = "Please check the form for errors."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def safe_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
