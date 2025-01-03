class VerificationsController < ApplicationController
  include Authentication

  def request_staff
    if Current.user.request_staff_verification
      redirect_to dashboard_path, notice: "Staff verification code has been sent to your email"
    else
      redirect_to dashboard_path, alert: "Only @wrantle.com email addresses can request staff verification"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_path, alert: "Error creating verification code: #{e.message}"
  end

  def request_admin
    if Current.user.request_admin_verification
      redirect_to dashboard_path, notice: "Admin verification code has been sent to your email"
    else
      redirect_to dashboard_path, alert: "Only @wrantle.com email addresses can request admin verification"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_path, alert: "Error creating verification code: #{e.message}"
  end

  def verify_staff
    Current.user.verify_staff!(params[:code])
    redirect_to dashboard_path, notice: "You are now verified as staff"
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: "Invalid or expired verification code"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_path, alert: "Error verifying staff status: #{e.message}"
  end

  def verify_admin
    Current.user.verify_admin!(params[:code])
    redirect_to dashboard_path, notice: "You are now verified as admin"
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: "Invalid or expired verification code"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to dashboard_path, alert: "Error verifying admin status: #{e.message}"
  end
end
