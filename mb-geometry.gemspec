require_relative 'lib/mb/geometry/version'

Gem::Specification.new do |spec|
  spec.name          = "mb-geometry"
  spec.version       = Mb::Geometry::VERSION
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

  spec.add_runtime_dependency 'rubyvor', '0.1.4'

  spec.add_development_dependency 'pry'
end
