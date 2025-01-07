namespace :sitemap do
  desc 'Generate the sitemap'
  task generate: :environment do
    puts 'Generating sitemap...'
    SitemapGenerator::Sitemap.verbose = true
    SitemapGenerator::Sitemap.create
    puts 'Sitemap generated successfully!'
  end
end
