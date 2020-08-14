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
