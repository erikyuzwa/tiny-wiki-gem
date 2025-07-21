# This is the main entry point for your gem.
# It requires other parts of your gem.

require "tiny_wiki/version"
require "tiny_wiki/app" # This will load your Sinatra application
require "fileutils" # Ensure FileUtils is available for directory operations

module TinyWiki
  # Main module for the gem.
  # No direct code here, it's primarily for namespacing.
end