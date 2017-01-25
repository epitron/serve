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

require 'sinatra'
require 'haml'
require 'socket'

require 'epitools/core_ext'

require_relative 'lib/utils'

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

  set :assets,     Pathname.new(__FILE__).expand_path.dirname / "assets"
  set :root_dir,   Pathname.new(public_dir).expand_path
  # set :public_folder, nil

  mime_type :mkv, 'video/x-matroska'
  disable :sessions

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
      "#{request.base_url}/#{"#{URI.escape @fullpath}/" if @fullpath.any?}#{path}"
    end

    def xsend_file(path)
      content_type path.extname, default: 'application/octet-stream'
      headers["X-Sendfile"] = path.to_s
    end
  end

  ###########################################################################

  def send_the_file(path)
    # xsend_file(path)
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
  get '/*' do |path|
    @path          = settings.root_dir / path
    @relative_path = @path.relative_to(settings.root_dir)
    @root_dir_name = settings.root_dir.basename
    @fullpath      = @relative_path.to_s
    @fullpath      = "" if @fullpath == "."

    return not_found unless @path.exists?

    #
    # Serve a file
    #
    unless @path.directory?
      return \
        case @path.extname
        when ".haml"
          haml @path.read, layout: false
        when ".md"
          markdown @path.read, layout: false
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
            send_the_file @path
          end
        end
    end


    #
    # Everything that's not a file
    #
    if params[:playlist] == "xspf"
      @tracks = @path.each_child.select(&:audio?)

      attachment("listen.xspf", "inline")
      content_type(".xspf")
      haml :xspf, layout: false

    elsif params[:search]
      # TODO: link to directories

      # SEARCH

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

      # Search directory tree for files
      # @matches = @path.find.select(&:exist?).map do |file|
      @matches = Dir["#{@path}/**/*"].select { |file| file =~ @query rescue nil }.map do |file|
        file = Pathname.new(file)
        next unless file.exists?
        rel = file.relative_to(@path)
        file if rel.to_s =~ @query
      end.compact

      # Group by dirs
      @grouped = @matches.group_by { |file| file.dirname }

      haml :search

    elsif feedtype = params[:rss]
      # RSS

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
      # FILES

      @sort  = params[:sort] || "name"
      @files = @path.children_sorted_by(@sort)

      if @order = params[:order]
        @files.reverse! if @order == "reversed"
      else
        @order = "forwards"
      end

      haml :files
    end
  end


  not_found do
    'Try again!'
  end

end
