# tiny_wiki.gemspec
# This file defines the gem's metadata, dependencies, and files.

Gem::Specification.new do |spec|
  spec.name          = "tiny_wiki"
  spec.version       = "0.2.0"
  spec.authors       = ["Erik Yuzwa"]
  spec.email         = ["erikyuzwa@gmail.com"]

  # This gem will work with 3.0 or greater...
  spec.required_ruby_version = '>= 3.0'

  spec.summary       = "A simple Markdown-based wiki server gem."
  spec.description   = "A Ruby gem that serves a wiki from Markdown files in a local directory."
  spec.homepage      = "https://github.com/erikyuzwa/tiny-wiki-gem"
  spec.license       = "MIT"

  # Specify which files should be added to the gem.
  #spec.files         = Dir.chdir(File.expand_path(__dir__)) do
  #  `git ls-files -z`.split("\x0").reject do |f|
  #    f.match(%r{^(test|spec|features)/})
  #  end
  #end

  spec.files = Dir.glob("lib/**/*", File::FNM_DOTMATCH)

  spec.bindir        = "exe"
  spec.executables   = %w[tiny_wiki_server]
  spec.require_paths = %w[lib]

  # Define runtime dependencies
  spec.add_runtime_dependency "sinatra", "~> 3.0"
  spec.add_runtime_dependency "redcarpet", "~> 3.0"
  spec.add_runtime_dependency "fileutils", "~> 1.7" # Typically included, but good to be explicit for clarity

  # Define development dependencies (for testing, etc.)
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end