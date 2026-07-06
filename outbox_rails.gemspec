require_relative "lib/outbox_rails/version"

Gem::Specification.new do |spec|
  spec.name        = "outbox_rails"
  spec.version     = OutboxRails::VERSION
  spec.authors     = [ "Wilbur Suero" ]
  spec.email       = [ "suerowilbur@gmail.com" ]
  spec.homepage    = "https://github.com/wilburhimself/outbox_rails"
  spec.summary     = "Transactional outbox implementation for Rails with observability."
  spec.description = "A production-ready implementation of the Outbox Pattern for Rails with metrics and observability."
  spec.license     = "MIT"

  spec.metadata["allowed_push_host"] = "TODO: Set to Gem cutter host"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.0"
end
