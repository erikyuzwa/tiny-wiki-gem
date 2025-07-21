# This is the main entry point for your gem.
# It requires other parts of your gem.

require "tiny_wiki_gem/version"
require "tiny_wiki_gem/app" # This will load your Sinatra application
require "fileutils" # Ensure FileUtils is available for directory operations

module TinyWikiGem
  # Main module for the gem.
  # No direct code here, it's primarily for namespacing.
end