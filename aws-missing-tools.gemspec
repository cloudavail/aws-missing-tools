# -*- encoding: utf-8 -*-
require File.expand_path('../lib/aws-missing-tools/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Colin Johnson', 'Anuj Biyani']
  gem.email         = %w(colin@cloudavail.com abiyani@lytro.com)
  gem.description   = %q{Extensions to Amazon's AWS CLI Tools.}
  gem.summary       = %q{A collection of useful tools to supplement the AWS CLI Tools. Many of these tools depend on official AWS tools to function.}
  gem.homepage      = 'https://github.com/colinbjohnson/aws-missing-tools/'

  gem.files         = `git ls-files`.split("\n")
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'aws-missing-tools'
  gem.require_paths = %w(lib)
  gem.version       = AwsMissingTools::VERSION

  gem.add_dependency 'aws-sdk', '~> 1.11'

  gem.add_development_dependency 'rspec', '~> 3.1'
end
