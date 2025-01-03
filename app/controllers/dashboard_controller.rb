class DashboardController < ApplicationController
  include Authentication

  def show
    @user = Current.user
  end
end
