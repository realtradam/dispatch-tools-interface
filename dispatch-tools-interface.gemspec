# frozen_string_literal: true

require_relative "lib/dispatch/tools/interface/version"

Gem::Specification.new do |spec|
  spec.name = "dispatch-tools-interface"
  spec.version = Dispatch::Tools::Interface::VERSION
  spec.authors = [ "Adam Malczewski" ]
  spec.email = [ "github@tradam.dev" ]

  spec.summary = "Structured interface for defining, validating, and executing tool definitions with JSON Schema."
  spec.description = "A Ruby gem that provides a structured interface for defining, validating, and executing tool definitions. Tools are defined with JSON Schema parameter validation and organized in a registry for lookup and execution."
  spec.homepage = "https://github.com/realtradam/dispatch-tools-interface"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/realtradam/dispatch-tools-interface"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  spec.add_dependency "json_schemer", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
