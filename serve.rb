#!/usr/bin/env ruby
###########################################################################
#
# TODO:
# - Save sort-order in session
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
# require 'tilt/haml'
# require 'tilt/coffee'

require 'socket'

require 'epitools/core_ext'
require 'epitools/rash'
require 'pathname'

###########################################################################

class Pathname

  alias_method :relative_to, :relative_path_from

  alias_method :ls,       :children
  alias_method :exists?,  :exist?
  alias_method :dir?,     :directory?

  def relative_name(root)
    dir = dir?
    name = relative_to(root).to_s
    dir ? "#{name}/" : name
  end

  def name
    if dir?
      "#{basename}/"
    else
      "#{basename}"
    end
  end


  TYPES = Rash.new(
    /\.(avi|ogm|webm|mpv|mp4|m4v|mkv|mj?pe?g|flv|mov|wmv)$/ => "video",
    /(^README|\.(pdf|doc|txt|srt|sub|nfo)$)/                => "doc",
    /\.(jpe?g|gif|png)$/                                    => "image",
    /\.(mp3|ogg|m4a|aac|flac)$/                             => "audio",
  )

  def type
    dir? ? "dir" : TYPES[basename.to_s] || "file"
  end

  def video?; type == "video"; end
  def audio?; type == "audio"; end
  def doc?;   type == "doc"; end
  def image?; type == "image"; end
  def media?; %w[audio video doc image].include? type; end

  def icon
    if dir?
      "/img/dir.gif"
    else
      "/img/#{type}.gif"
    end
  end



  SORT_METHOD = {
    "date" => :cmp_date,
    "size" => :cmp_size,
    "type" => :cmp_type,
    "name" => :cmp_name,
  }

  def children_sorted_by(sort="name")
    method = SORT_METHOD[sort] || :cmp_name
    children.select(&:exist?).sort_by &method
  end

  def cmp_date
    -mtime.to_i
  end

  def cmp_size
    [dir? ? 0 : -size, cmp_name]
  end

  def cmp_type
    [type, cmp_name]
  end

  def cmp_name
    [dir? ? 0 : 1, to_s.downcase]
  end


  #
  # Read xattrs from file (requires "getfattr" to be in the path)
  #
  def getxattrs
    # # file: Scissor_Sisters_-_Invisible_Light.flv
    # user.m.options="-c"

    cmd = %w[getfattr -d -m - -e base64] + [realpath.to_s]

    attrs = {}

    IO.popen(cmd, "rb", :err=>[:child, :out]) do |io|
      io.each_line do |line|
        if line =~ /^([^=]+)=0s(.+)/
          key   = $1
          value = $2.from_base64 # unpack base64 string
          # value = value.encode("UTF-8", "UTF-8") # set string's encoding to UTF-8
          value = value.force_encoding("UTF-8").scrub  # set string's encoding to UTF-8
          # value = value.encode("UTF-8", "UTF-8")  # set string's encoding to UTF-8

          attrs[key] = value
        end
      end
    end

    attrs
  end

end

###########################################################################

class Time
  def formatted_like_ls
    if year == Time.now.year
      fmt = "%b %d %H:%M"
    else
      fmt = "%b %d %Y"
    end

    strftime(fmt)
  end

  def rfc822
    strftime("%a, %-d %b %Y %T %z")
  end
  alias_method :rss, :rfc822
end

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

    def url_for(relative_path)
      "#{request.base_url}/#{"#{@fullpath}/" if @fullpath.any?}#{relative_path}"
    end

    def xsend_file(path)
      headers["X-Sendfile"] = path
    end
  end

  ###########################################################################

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
            send_file @path
          else
            haml :swf, layout: false
          end
        else
          case request.env["HTTP_ACCEPT"]
          when "metadata", "application/metadata+json"
            @path.getxattrs.to_json
          else
            send_file @path
          end
        end
    end

    #
    # Everything that's not a file
    #
    if params[:search]
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
