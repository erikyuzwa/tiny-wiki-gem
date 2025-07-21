# This file contains the Sinatra web application logic.

require 'sinatra/base'
require 'redcarpet'
require 'fileutils'
require 'uri' # For URI encoding/decoding

module TinyWiki
  class App < Sinatra::Base
    # Configuration for the Sinatra app
    # Set the binding address to listen on all interfaces (0.0.0.0)
    set :bind, '0.0.0.0'
    # Set the default port
    set :port, 4567
    # Set the root directory for the Sinatra app (where templates are)
    set :root, File.expand_path('../..', __FILE__)
    # Set the views directory for ERB templates
    set :views, File.join(settings.root, 'tiny_wiki', 'templates')
    # Enable sessions for flash messages (optional, but good for feedback)
    enable :sessions

    # Custom Redcarpet renderer to handle wiki links (e.g., [[Page Name]])
    class WikiLinkRenderer < Redcarpet::Render::HTML
      # The postprocess method is called after all other rendering is complete.
      # We use it to find and replace our custom wiki link syntax.
      def postprocess(full_document)
        full_document.gsub(/\[\[(.*?)\]\]/) do
          page_name = $1.strip # Get the text inside the brackets
          # Sanitize page name for URL: replace spaces with underscores, then URI encode
          url_safe_page_name = URI.encode_www_form_component(page_name.gsub(' ', '_'))
          "<a href=\"/#{url_safe_page_name}\">#{page_name}</a>"
        end
      end
    end

    # Markdown renderer setup
    # Create a Redcarpet renderer that uses HTML with code highlighting and auto-links.
    # The `fenced_code_blocks` and `autolink` extensions are common and useful.
    markdown_renderer = WikiLinkRenderer.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" },
      prettify: true,
      with_toc_data: true
    )
    # Create the Redcarpet Markdown object with desired extensions
    @@markdown = Redcarpet::Markdown.new(
      markdown_renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      superscript: true,
      highlight: true,
      quote: true,
      footnotes: true
    )

    # Helper method to get the full path to a markdown file
    # `page_name` is expected to be URL-decoded and safe for filenames.
    def wiki_file_path(page_name)
      # Ensure the page name doesn't contain directory traversal attempts
      # This is a basic sanitization. For production, more robust checks are needed.
      sanitized_page_name = page_name.gsub(/[^a-zA-Z0-9_\-]/, '') # Allow only alphanumeric, underscore, hyphen
      File.join(settings.wiki_root, "#{sanitized_page_name}.md")
    end

    # Helper method to read the content of a wiki page
    def read_page(page_name)
      path = wiki_file_path(page_name)
      File.exist?(path) ? File.read(path) : nil
    end

    # Helper method to write content to a wiki page
    def write_page(page_name, content)
      path = wiki_file_path(page_name)
      # Ensure the directory exists
      FileUtils.mkdir_p(File.dirname(path)) unless File.directory?(File.dirname(path))
      File.write(path, content)
    end

    # Helper method to convert Markdown to HTML
    def markdown_to_html(markdown_content)
      @@markdown.render(markdown_content)
    end

    # Helper to get all wiki pages (filenames without extension)
    def all_wiki_pages
      Dir.glob(File.join(settings.wiki_root, '*.md')).map do |file|
        File.basename(file, '.md')
      end.sort
    rescue Errno::ENOENT
      # If the wiki_root directory doesn't exist yet, return an empty array
      []
    end

    # --- Routes ---

    # Redirect root to a default page (e.g., 'Home')
    get '/' do
      redirect to('/Home')
    end

    # List all wiki pages
    get '/_list' do
      @pages = all_wiki_pages
      erb :list # Render a 'list.erb' template (you'll need to create this)
    end

    # Display a wiki page
    get '/:page_name' do
      @page_name = URI.decode_www_form_component(params[:page_name])
      @markdown_content = read_page(@page_name)

      if @markdown_content
        @html_content = markdown_to_html(@markdown_content)
        erb :show # Render 'show.erb'
      else
        # Page not found, redirect to edit page
        session[:message] = "Page '#{@page_name}' does not exist. Create it!"
        redirect to("/#{@page_name}/edit")
      end
    end

    # Show the edit form for a wiki page
    get '/:page_name/edit' do
      @page_name = URI.decode_www_form_component(params[:page_name])
      @markdown_content = read_page(@page_name) || "" # Empty string if new page
      erb :edit # Render 'edit.erb'
    end

    # Save the content of a wiki page
    post '/:page_name' do
      @page_name = URI.decode_www_form_component(params[:page_name])
      new_content = params[:content]

      if new_content && !new_content.strip.empty?
        write_page(@page_name, new_content)
        session[:message] = "Page '#{@page_name}' saved successfully!"
        redirect to("/#{@page_name}")
      else
        session[:message] = "Page content cannot be empty!"
        redirect to("/#{@page_name}/edit") # Redirect back to edit with error
      end
    end

    # Handle 404 errors (page not found)
    not_found do
      status 404
      "<h1>404 - Page Not Found</h1><p>The page you requested does not exist.</p><p><a href='/'>Go Home</a></p>"
    end
  end
end