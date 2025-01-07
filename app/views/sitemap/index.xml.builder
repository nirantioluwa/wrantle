xml.instruct!
xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
  # Add root path
  xml.url do
    xml.loc @host
    xml.changefreq "daily"
    xml.priority 1.0
  end

  # Add static pages with their frequencies
  {
    # Main pages
    services_path => "weekly",
    about_path => "monthly",

    # Strategy pages
    global_corporate_strategy_path => "monthly",
    intellectual_property_path => "monthly",
    finance_and_investments_path => "monthly",
    legal_and_compliance_path => "monthly",
    operational_excellence_path => "monthly",
    risk_esg_and_governance_path => "monthly",

    # Additional pages
    single_north_star_path => "monthly",
    live_impact_thrive_path => "monthly",
    impact_beyond_us_path => "monthly",
    modern_innovator_challenge_path => "monthly",
    accelerating_business_growth_path => "monthly",
    building_for_tomorrow_path => "monthly",

    # Public forms
    new_contact_path => "monthly"
  }.each do |path, frequency|
    xml.url do
      xml.loc "#{@host}#{path}"
      xml.changefreq frequency
      xml.priority 0.8
    end
  end

  # Add published writings using slugs
  @writings.each do |writing|
    xml.url do
      xml.loc "#{@host}/writings/#{writing.slug}"
      xml.lastmod writing.updated_at.strftime("%Y-%m-%d")
      xml.changefreq "weekly"
      xml.priority 0.6
    end
  end
end
