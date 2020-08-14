class String
  def urlencode
    ERB::Util.url_encode(self).gsub("%2F", "/")
  end
end

