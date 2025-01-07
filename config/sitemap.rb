# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://#{ENV['HOST_NAME']}" # You'll need to set this in your environment

SitemapGenerator::Sitemap.create do
  # Add root path
  add root_path, changefreq: "daily", priority: 1.0

  # Add static pages
  add services_path, changefreq: "weekly"
  add about_path, changefreq: "monthly"
  add global_corporate_strategy_path, changefreq: "monthly"
  add intellectual_property_path, changefreq: "monthly"
  add finance_and_investments_path, changefreq: "monthly"
  add legal_and_compliance_path, changefreq: "monthly"
  add operational_excellence_path, changefreq: "monthly"
  add risk_esg_and_governance_path, changefreq: "monthly"

  # Add dynamic content
  Writing.published.find_each do |writing|
    add writing_path(writing), lastmod: writing.updated_at, changefreq: "weekly"
  end
end
