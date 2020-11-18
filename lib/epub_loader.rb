require 'epub/parser'
require 'oga'

class EPUBLoader

  def initialize(path)
    @path = path
  end

  def epub
    @epub ||= EPUB::Parser.parse(@path)
  end

  def anchorify(href)
    href.to_s.gsub(/\s/, '_')
  end

  def join_paths(base, path)
    base = Pathname.new(base.to_s).dirname
    path = Pathname.new(path.to_s)
    base.join(path).to_s
  end

  def file(path)
    epub.manifest.items.find { |item| item.href.to_s == path }
  end

  def each_page
    epub.each_page_on_spine do |page|
      p page.href if $debug_mode

      doc  = Oga.parse_html(page.read)
      body = doc.at_css("body")

      # convert chapter links into intra-page anchors
      body.css("a").each do |link|
        p link if $debug_mode
        if href = link["href"]
          next if href[%r{^https?://}]

          if href =~ /^.*(#.+)$/
            link["href"] = $1
          else
            link["href"] = '#' + anchorify(join_paths(page.href, href))
          end
        end
      end

      # rewrite image links
      body.css("img").each do |img|
        img['src'] = "?file=#{join_paths page.href, img['src']}"
      end

      # rewrite svg image links
      body.css("image").each do |image|
        image["xlink:href"] = "?file=#{join_paths page.href, image['xlink:href']}"
      end

      page_html = body.to_xml.sub(%r{\A<body[^>]*>}, '').sub(%r{</\s*body[^>]*>\z}, '')

      result = <<~HTML
        <page>
          <a name='#{anchorify(page.href)}'></a>
          #{page_html}
        </page>

      HTML

      # puts result
      # binding.pry
      yield result
    end
  end

end

if __FILE__ == $0
  $debug_mode = true

  epub = EPUBLoader.new("#{__dir__}/../test2.epub")
  epub.each_page do |page|
    puts page
    puts "--------------------------------------------------------------------------------------------------------------------"
    puts
  end

  puts "cover_image.jpg: #{epub.file("cover_image.jpg").read.size} bytes"
end
