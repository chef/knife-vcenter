source "https://rubygems.org"

gemspec

group :docs do
  gem "github-markup"
  gem "redcarpet"
  gem "yard"
end

group :test do
  gem "chefstyle", "~> 1.0"
  gem "rake", ">= 10.0"
  gem "rspec", "~> 3.7"
  gem "rubocop-rspec", "~> 1.18"
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7")
    gem "chef-zero", "~> 15"
    gem "chef", "~> 16"
  end
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
  gem "rb-readline"
end
