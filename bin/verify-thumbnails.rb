$: << "#{__dir__}/lib"

require 'core_ext'
require 'chunky_png'
require 'epitools/colored'

mismatched = []

Pathname::THUMBDIR.glob("*.png").each do |thumb|
  hash = thumb.basename.to_s.gsub(".png", '')
  # puts hash

  im  = ChunkyPNG::Image.from_file(thumb)
  uri = im.metadata["Thumb::URI"]

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
      end
    else
      puts "#{hash} [not found] #{uri.inspect}".light_red
      thumb.unlink
    end
  end

  # puts "#{fn}: #{uri}"if uri[/%[^2][^0]/]
end

pp mismatched