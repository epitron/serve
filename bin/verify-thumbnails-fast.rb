$: << "#{__dir__}/lib"

require 'core_ext'
# require 'chunky_png'
# require 'epitools/colored'
# require 'epitools/core_ext/enumerable'
require 'epitools'

mismatched = []

IO.popen(["exiftool", *Dir["#{Pathname::THUMBDIR}/*.png"]]) do |io|
  io.each_line.lazy.split_before(/^===/).each do |r|
    next if r.empty?

    metadata = r[1..-1].map { |l| a,b = l.split(/\s+: /); b&.chomp!; [a,b] }.to_h
    fn       = metadata["File Name"]
    uri      = metadata["Thumb URI"]
    thumb    = Pathname::THUMBDIR/fn
    hash     = fn.gsub(".png", '')

    if uri.nil?
      puts "#{hash} [no URI]".light_red
      thumb.unlink
    else
      src = Pathname.new(uri.gsub(%r{^file://}, ''))
      if src.exists?
        if src.thumbnail == thumb
          # puts "  [found] and [matches]".light_green
        else
          puts "#{hash} [found] and [NOT match] #{src}".light_yellow
          puts "  expected: #{uri}"
          puts "    actual: #{src.local_uri}"
          mismatched << [src.thumbnail, thumb]
          thumb.unlink
        end
      else
        puts "#{hash} [not found] #{uri.inspect}".light_red
        thumb.unlink
      end
    end

  end

  # puts "#{fn}: #{uri}"if uri[/%[^2][^0]/]
end

pp mismatched