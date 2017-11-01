# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'knife-vcenter/version'

Gem::Specification.new do |spec|
  spec.name          = 'knife-vcenter'
  spec.version       = KnifeVcenter::VERSION
  spec.authors       = ['Chef Partner Engineering']
  spec.email         = ['partnereng@chef.io']
  spec.summary       = 'Knife plugin to VMware vCenter.'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/chef/knife-vcenter'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'knife-cloud',  '~> 1.2'
  spec.add_dependency 'rb-readline', '~> 0.5'
  spec.add_dependency 'rbvmomi', '~> 1.11'
  spec.add_dependency 'savon', '~> 2.11'
  spec.add_dependency 'vsphere-automation-sdk', '~> 6.6'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'debase'
  spec.add_development_dependency 'github_changelog_generator'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake',    '~> 10.0'
  spec.add_development_dependency 'rubocop', '~> 0.35'
  spec.add_development_dependency 'ruby-debug-ide', '~> 0.6.0'
  spec.add_development_dependency 'yard'

end
