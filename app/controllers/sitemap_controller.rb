class SitemapController < ApplicationController
  allow_unauthenticated_access
  def index
    # Set headers
    headers["Content-Type"] = "application/xml"
    headers["Cache-Control"] = "public, max-age=14400" # Cache for 4 hours

    @host = "https://wrantle.com"

    # Get only published writings that are currently published (not scheduled for future)
    @writings = Writing.published.order(published_at: :desc)

    respond_to do |format|
      format.xml
    end
  end
end
