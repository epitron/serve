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
