require 'epitools/rash'
require 'pathname'
require 'digest/md5'

###########################################################################

class Pathname

  TYPES = [
    [/\.(avi|ogm|webm|mp4|m4v|mkv|mj?pe?g|flv|f4v|mov|wmv|asf)$/i, "video"],
    [/(^README|\.(pdf|doc|txt|srt|sub|nfo)$)/i               , "doc"],
    [/\.(jpe?g|gif|png|webp)$/i                              , "image"],
    [/\.(mp3|ogg|m4a|aac|flac)$/i                            , "audio"],
  ]
  # TYPES = Rash.new(
  #   /\.(avi|ogm|webm|mp4|m4v|mkv|mj?pe?g|flv|f4v|mov|wmv)$/i => "video",
  #   /(^README|\.(pdf|doc|txt|srt|sub|nfo)$)/i                => "doc",
  #   /\.(jpe?g|gif|png|webp)$/i                               => "image",
  #   /\.(mp3|ogg|m4a|aac|flac)$/i                             => "audio",
  # )

  def file_type
    return "directory" if directory?
    result = TYPES.find { |re, t| re.match(to_s) }
    result && result.last
  end

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

  def name_without_ext
    extname.blank? ? name : name.gsub(/#{Regexp.escape extname}$/, '')
  end

  def type
    dir? ? "dir" : basename.file_type || "file"
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

  def local_uri
    # RFC2396
    "file://#{expand_path}".gsub(" ", "%20")
  end

  THUMBDIR = Pathname.new("~/.cache/thumbnails/large/").expand_path

  def thumbnail
    hash = Digest::MD5.hexdigest(local_uri)
    (THUMBDIR/"#{hash}.png").expand_path
  end

  def thumbnail!(overwrite=false)
    return true if thumbnail.exists? and not overwrite

    case file_type
    when "video", "image"
      cmd = [
          "ffmpeg",
          # "-loglevel", "quiet",
          # "-noaccurate_seek",
          # "-ss", "40",

          "-i", to_path,

          "-frames:v", "1",
          "-an",

          # "-vf", "thumbnail,scale=256:-1,crop=256:256",
          "-vf", "thumbnail,scale=256:256:force_original_aspect_ratio=increase,crop=256:256",
          # "-vf", "scale=256:-1",

          "-y", thumbnail.to_path,
      ]
      system(*cmd)
    else
      false
    end
  end

end

###########################################################################
