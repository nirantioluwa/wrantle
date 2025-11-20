# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Add Primer ViewComponents assets from node_modules
# These paths allow Propshaft to find and serve Primer CSS/JS files
Rails.application.config.assets.paths << Rails.root.join("node_modules/@primer/css/dist")
Rails.application.config.assets.paths << Rails.root.join("node_modules/@primer/primitives/dist")
Rails.application.config.assets.paths << Rails.root.join("node_modules/@primer/view-components/app/assets")
