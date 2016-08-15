# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef_zabbix/version'

Gem::Specification.new do |spec|
  spec.name          = 'chef-zabbix'
  spec.version       = ChefZabbix::VERSION
  spec.authors       = ['Austin Heiman']
  spec.email         = ['atheimanksu@gmail.com']

  spec.summary       = %q{Library for integrating Chef and Zabbix}
  spec.homepage      = 'https://github.com/atheiman/chef-zabbix'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'zabbixapi', '~> 2.2.0'
  spec.add_dependency 'ridley', '~> 5.0'
  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
