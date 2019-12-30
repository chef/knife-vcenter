source "https://rubygems.org"

gemspec

group :docs do
  gem "github-markup"
  gem "redcarpet"
  gem "yard"
end

group :test do
  gem "chefstyle"
  gem "rake"
  gem "rspec", "~> 3.7"
  gem "rubocop-rspec", "~> 1.18"
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.5")
    gem "ohai", "<15"
    gem "chef", "<15"
    gem "knife-cloud", "~> 1.2"
  end
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
  gem "rb-readline"
end
