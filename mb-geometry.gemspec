require_relative 'lib/mb/geometry/version'

Gem::Specification.new do |spec|
  spec.name          = "mb-geometry"
  spec.version       = MB::Geometry::VERSION
  spec.authors       = ["Mike Bourgeous"]
  spec.email         = ["mike@mikebourgeous.com"]

  spec.summary       = %q{Recreational Ruby tools for graphics and geometry.}
  spec.homepage      = "https://github.com/mike-bourgeous/mb-geometry"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.1")

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mike-bourgeous/mb-geometry"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'csv', '~> 3.3', '>= 3.3.3'

  spec.add_runtime_dependency 'rubyvor', '0.1.4'
  spec.add_runtime_dependency 'georuby' # rubyvor depends on GeoRuby which hasn't been updated

  spec.add_runtime_dependency 'numo-narray', '~> 0.9.2.1'

  spec.add_runtime_dependency 'mb-math', '>= 0.2.2.usegit'
  spec.add_runtime_dependency 'mb-util', '>= 0.1.20.usegit'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rspec', '~> 3.10.0'

  spec.add_development_dependency 'rmagick'

  spec.add_development_dependency 'simplecov', '~> 0.21.2'
end
