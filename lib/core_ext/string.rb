class String
  def urlencode
    #ERB::Util.url_encode(self).gsub("%2F", "/")
    @@parser ||= URI::RFC2396_Parser.new
    @@parser.escape(self)
  end
  alias_method :urlescape, :urlencode
end

