require_relative 'serve'

# require 'logger'
# use Rack::CommonLogger, Logger.new('access.log')

# use Rainbows::Sendfile
# use Rack::Reloader, 0
# use Rack::ContentLength

run MediaServer
