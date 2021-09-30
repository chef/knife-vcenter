source "https://rubygems.org"

gemspec

group :docs do
  gem "github-markup"
  gem "redcarpet"
  gem "yard"
end

group :test do
  gem "chefstyle", "~> 2.1"
  gem "rake", ">= 10.0"
  gem "rspec", "~> 3.7"
  gem "rubocop-rspec", "~> 2.0"
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7")
    gem "chef-zero", "~> 15"
    gem "chef", "~> 15"
  end
end

group :debug do
  gem "pry"
  gem "pry-byebug"
  gem "pry-stack_explorer"
  gem "rb-readline"
end
