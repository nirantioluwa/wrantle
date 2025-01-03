class DashboardController < ApplicationController
  include Authentication
  before_action :set_user

  def show
  end

  def verification
  end

  private

  def set_user
    @user = Current.user
  end
end
