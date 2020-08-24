#!/usr/bin/env ruby
###########################################################################
#
# TODO:
# - Persistent directory sort-order (cookie-based)
#
###########################################################################

# if ARGV.any? { |arg| ["-h", "--help"].include? arg }
#   puts
#   puts "usage:"
#   puts "  serve <directory> [host[:port]]"
#   puts
#   exit
# end

###########################################################################

# if __FILE__[/serve-dev\.rb$/]
#   require 'sinatra/reloader'
# else
#   ENV["RACK_ENV"] = "production"
# end

$:.unshift "#{__dir__}/lib"

require 'sinatra'
require 'haml'
require 'socket'
require 'erb'
require 'epub/parser'

require 'epitools/core_ext'

require 'core_ext/string'
require 'core_ext/time'
require 'core_ext/pathname'

require 'moin2markdown'

###########################################################################

class MediaServer < Sinatra::Base

  # Defaults
  # port       = 8888
  # host       = "0.0.0.0"
  public_dir = Dir.pwd

  # # Parse commandline arguments (root dir or port)
  # ARGV.each do |arg|
  #   case arg
  #   when /^\d{2,5}$/
  #     port = arg.to_i
  #   when /^(\w+):(\d+)$/, /^([\d\.]+):(\d+)$/
  #     host = $1
  #     port = $2.to_i
  #   else
  #     if File.directory? arg
  #       public_dir = arg
  #     else
  #       puts "Error: #{arg.inspect} is not a directory."
  #       exit 1
  #     end
  #   end
  # end

  ###########################################################################

  # begin
  #   require 'puma'
  #   set :server, :puma
  # rescue LoadError
  # end

  set :machine_name, Socket.gethostname

  # set :bind, host
  # set :port, port

  set :assets,     Pathname.new(__FILE__).expand_path.dirname / "public"
  set :root_dir,   Pathname.new(public_dir).expand_path
  # set :public_folder, nil

  mime_type :mkv, 'video/x-matroska'
  mime_type :nfo, 'text/plain; charset=IBM437'
  # disable :sessions

  # puts %q{
  #  ____                  _                                  _ _
  # / ___|  ___ _ ____   _(_)_ __   __ _   _ __ ___   ___  __| (_) __ _
  # \___ \ / _ \ '__\ \ / / | '_ \ / _` | | '_ ` _ \ / _ \/ _` | |/ _` |
  #  ___) |  __/ |   \ V /| | | | | (_| | | | | | | |  __/ (_| | | (_| |_ _ _
  # |____/ \___|_|    \_/ |_|_| |_|\__, | |_| |_| |_|\___|\__,_|_|\__,_(_|_|_)
  #                                |___/             }
  # puts
  # puts "ADDRESS: http://#{host}:#{port}/"
  # puts " SOURCE: #{settings.root_dir}"
  # puts

  ###########################################################################

  helpers do
    def highlight(thing, regexp)
      thing.to_s.gsub(regexp) { |m| "<mark>#{m}</mark>" }
    end

    def current_full_url
      "#{request.base_url}#{request.fullpath}"
    end

    def current_url
      "#{request.base_url}#{request.path}"
    end

    def url_for(path)
      "#{request.base_url}/#{"#{@fullpath.urlencode}/" if @fullpath.any?}#{path}"
    end

    def xsend_file(path)
      content_type path.extname, default: 'application/octet-stream'
      headers["X-Sendfile"] = path.to_s
    end
  end

  ###########################################################################

  def heap_size
    # size     total program size (pages)            (same as VmSize in status)
    # resident size of memory portions (pages)       (same as VmRSS in status)
    # shared   number of pages that are shared       (i.e. backed by a file, same
    #                                           as RssFile+RssShmem in status)
    # trs      number of pages that are 'code'       (not including libs; broken,
    #                                           includes data segment)
    # lrs      number of pages of library            (always 0 on 2.6)
    # drs      number of pages of data/stack         (including libs; broken,
    #                                           includes library text)
    # dt       number of dirty pages                 (always 0 on 2.6)

    size, resident, shared, trs, lrs, drs, dt = File.read("/proc/#{$$}/statm").split.map(&:to_i)
    resident
  end

  def send_the_file(path)
    # xsend_file(path)
    puts "[sending] #{path}"
    send_file(path.open)
  end

  def flip_order(order)
    order == "reversed" ? "forwards" : "reversed"
  end

  def sort_params(field, current_sort, current_order)
    current_sort ||= "name"
    next_order     = "forwards"
    next_order     = flip_order(current_order) if current_sort == field

    "?sort=#{field}&order=#{next_order}"
  end

  ###########################################################################
  #
  # Secret assets directory
  #
  # get '/_/*' do |path|
  #   if path == "default.css"
  #     content_type :css
  #     settings.templates[:css].first
  #   elsif path == "main.js"
  #     content_type :js
  #     settings.templates[:js].first
  #   else
  #     send_file settings.assets / path
  #   end
  # end

  #
  # Regular directories
  #

  OPTIONAL_EXTS = %w[.haml .moin .md .html]

  get '/*' do |path|
    @path          = settings.root_dir / path
    @relative_path = @path.relative_to(settings.root_dir)
    @root_dir_name = settings.root_dir.basename
    @fullpath      = @relative_path.to_s
    @fullpath      = "" if @fullpath == "."

    # puts "[requested] #{@path}"
    puts "[requested] #{request.fullpath}"

    unless @path.exists?
      unless OPTIONAL_EXTS.any? { |ext| testpath = @path.sub_ext(ext); testpath.exist? ? @path = testpath : false }
        return not_found
      end
    end
    # require 'pry'; binding.pry


    #
    # Serve a file
    #
    unless @path.directory?
      return \
        case @path.extname
        when ".haml"
          haml @path.read, layout: false

        when ".moin"
          haml(:"layout-markdown", layout: false) do
            markdown(moin2markdown(@path.read))
          end

          # haml markdown(moin2markdown(@path.read)), layout: :"layout-markdown"
          # markdown moin2markdown(@path.read), layout: :"layout-markdown"

        when ".md"
          haml(:"layout-markdown", layout: false) do
            markdown(@path.read)
          end
          # markdown @path.read, layout: false

        when ".epub"
          # TODO: Only render <body> of each page
          # TODO: make the ToC work (options: 1. rewrite the ToC so hrefs become #hashes and there's a <a name> before each chapter, or 2. only render one chapter at a time chapter, linked from ToC, and put a next>> at the end of each chapter)
          epub = EPUB::Parser.parse(@path)

          # haml(:"layout-markdown", layout: false) do
            Enumerator.new do |out|
              epub.each_page_on_spine do |page|
                out << page.read
                out << "<br>"
              end
            end
          # end

        when ".swf"
          if params[:file]
            send_the_file @path
          else
            haml :swf, layout: false
          end

        else
          case request.env["HTTP_ACCEPT"]
          when "metadata", "application/metadata+json"
            @path.getxattrs.to_json
          else
            if params[:thumbnail]
              @path.thumbnail! unless @path.thumbnail.exists?
              content_type(".png")
              send_the_file @path.thumbnail
            else
              send_the_file @path
            end
          end
        end
    end

    #
    # Everything that's not a file
    #
    if params[:playlist] == "audio-xspf"
      # PLAY DIRECTORY AS XSPF PLAYLIST
      @tracks = @path.each_child.select(&:audio?)

      attachment("listen.xspf", "inline")
      content_type(".xspf")
      haml "audio-xspf", layout: false

    elsif params[:playlist] == "video-m3u"

      attachment("watch.m3u", "inline")
      content_type(".m3u")

      @path.each_child.select(&:video?).map do |path|
        url_for(path.basename.to_s.urlencode)
      end.join("\n")

    elsif params[:playlist] == "video-pls"

      attachment("watch.pls", "inline")
      content_type(".pls")

      out = []
      out << "[playlist]"

      @vidz = @path.each_child.select(&:video?)

      @vidz.each_with_index do |path, n|
        out << "Title#{n+1}=#{path.basename}"
        out << "File#{n+1}=#{url_for(path.basename.to_s.urlencode)}"
      end

      out << "NumberOfEntries=#{@vidz.size}"

      out.join("\n")

    elsif params[:search]
      # SEARCH

      # TODO: link to parent directories

      if params[:throbber]
        @redirect = "/#{path}?search=#{params[:search]}"
        return haml :throbber
      end

      # Turn query into a regexp
      union = Regexp.union params[:search].split
      @query = /#{union.source}/i

      # @matches = @path.find.select(&:exist?).map do |file|
      #   begin
      #     rel = file.relative_to(@path)
      #     file if rel.to_s =~ @query
      #   rescue ArgumentError
      #   end
      # end.compact

      ## Search directory tree for files
      # @matches = @path.find.select(&:exist?).map do |file|
      @matches = Dir["#{@path}/**/*"].select { |file| file =~ @query rescue nil }.map do |file|
        file = Pathname.new(file)
        next unless file.exists?
        rel = file.relative_to(@path)
        # @path = unless @path.to_path[%r{/$}]
        # puts(rel: rel, file: file, path: @path)
        file if rel.to_s =~ @query
      end.compact

      # Group by dirs
      @grouped = @matches.group_by { |file| file.dirname }

      haml :search

    elsif feedtype = params[:rss]
      # RSS FEED

      @files = @path.children_sorted_by("date")

      case feedtype
      when "video"
        @files = @files.select(&:video?)
      when "audio"
        @files = @files.select(&:audio?)
      when "doc"
        @files = @files.select(&:doc?)
      else
        @files = @files.select(&:media?)
      end

      content_type :atom
      # application/atom+xml
      haml :rss, layout: false

    else
      # DIRECTORY INDEX
      return redirect "#{current_url}/" unless current_url[%r{/$}]

      if params[:thumbnail]
        content_type(".gif")
        send_the_file settings.assets/"img/dir.gif"
      else
        @sort  = params[:sort] || "name"
        @files = @path.children_sorted_by(@sort).reject {|path| path.basename.to_s[/^\./] or path.extname == ".srt" }

        if @order = params[:order]
          @files.reverse! if @order == "reversed"
        else
          @order = "forwards"
        end

        haml :files
      end
    end

  end


  not_found do
    'Try again!'
  end

end

