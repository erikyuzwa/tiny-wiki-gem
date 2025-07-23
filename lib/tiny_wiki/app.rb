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
          raw_page_path = $1.strip # e.g., "Folder/Page Name"

          # Split the path into components
          path_components = raw_page_path.split('/')

          # Sanitize each component and convert spaces to underscores for the URL
          # Then URI encode each component
          url_safe_components = path_components.map do |comp|
            # Replace spaces with underscores for URL segment
            sanitized_comp = comp.gsub(' ', '_')
            # URI encode the individual component
            URI.encode_www_form_component(sanitized_comp)
          end

          # Rejoin with '/' to form the URL path
          url_path = url_safe_components.join('/')

          "<a href=\"/#{url_path}\">#{raw_page_path}</a>"
        end
      end
    end

    # Markdown renderer setup
    # Create a Redcarpet renderer that uses HTML with code highlighting and auto-links.
    # The `fenced_code_blocks` and `autolink` extensions are common and useful.
    markdown_renderer = WikiLinkRenderer.new( # Use our custom renderer here
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
    # `page_path` is expected to be URL-decoded and can contain slashes.
    def wiki_file_path(page_path)
      # Normalize path to prevent directory traversal (e.g., /foo/../bar)
      # Split by '/' and reject empty components, '.' and '..'.
      # Then re-join to form a safe relative path.
      safe_components = page_path.split('/').reject { |c| c.empty? || c == '.' || c == '..' }

      # Reconstruct the path. File.join handles OS-specific separators.
      File.join(settings.wiki_root, "#{safe_components.join('/')}.md")
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

    # Helper to get all wiki pages (filenames without extension, including paths)
    def all_wiki_pages
      # Find all .md files recursively within the wiki_root
      Dir.glob(File.join(settings.wiki_root, '**', '*.md')).map do |file_path|
        # Get the path relative to wiki_root and remove the .md extension
        # Example: /path/to/wiki_root/Folder/Page.md -> Folder/Page
        relative_path_with_ext = file_path.sub("#{settings.wiki_root}/", '')
        relative_path_with_ext.sub(/\.md$/, '')
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

    # Handle favicon.ico requests directly to avoid treating them as wiki pages
    get '/favicon.ico' do
      # You can serve an actual favicon.ico file here if you have one.
      # For now, we'll just return a 404 to prevent redirection.
      status 404
      '' # Return empty body
    end

    # Handle Chrome DevTools specific requests
    get '/.well-known/appspecific/com.chrome.devtools.json' do
      status 404
      '' # Return empty body
    end

    # List all wiki pages
    get '/_list' do
      @pages = all_wiki_pages
      erb :list # Render a 'list.erb' template (you'll need to create this)
    end

    # Show the edit form for a wiki page
    # The splat parameter `*page_path` will match multiple path segments, including slashes.
    get '/*page_path/edit' do
      @page_name = URI.decode_www_form_component(params[:page_path])
      @markdown_content = read_page(@page_name) || "" # Empty string if new page
      puts "DEBUG: Rendering edit form for page: #{@page_name}" # DEBUG
      erb :edit
    end

    # Save the content of a wiki page
    # The splat parameter `*page_path` will match multiple path segments, including slashes.
    post '/*page_path' do
      @page_name = URI.decode_www_form_component(params[:page_path])
      new_content = params[:content]
      puts "DEBUG: POST request to save page: #{@page_name}" # DEBUG
      puts "DEBUG: Content received: #{new_content.inspect}" # DEBUG

      if new_content && !new_content.strip.empty?
        write_page(@page_name, new_content)
        session[:message] = "Page '#{@page_name}' saved successfully!"
        puts "DEBUG: Page saved, redirecting to /#{@page_name}" # DEBUG
        redirect to("/#{@page_name}")
      else
        session[:message] = "Page content cannot be empty!"
        puts "DEBUG: Empty content, redirecting to /#{@page_name}/edit" # DEBUG
        redirect to("/#{@page_name}/edit")
      end
    end

    # Display a wiki page
    # The splat parameter `*page_path` will match multiple path segments, including slashes.
    get '/*page_path' do
      @page_name = URI.decode_www_form_component(params[:page_path])
      @markdown_content = read_page(@page_name)

      if @markdown_content
        @html_content = markdown_to_html(@markdown_content)
        erb :show
      else
        # Page not found, redirect to edit page
        session[:message] = "Page '#{@page_name}' does not exist. Create it!"
        # Ensure the page_name doesn't already end with '/edit' before redirecting
        clean_page_name_for_redirect = @page_name.sub(/\/edit$/, '')
        puts "DEBUG: Redirecting to edit for non-existent page: /#{clean_page_name_for_redirect}/edit" # DEBUG
        redirect to("/#{clean_page_name_for_redirect}/edit")
      end
    end

    

    # Handle 404 errors (page not found)
    not_found do
      status 404
      "<h1>404 - Page Not Found</h1><p>The page you requested does not exist.</p><p><a href='/'>Go Home</a></p>"
    end
  end
end