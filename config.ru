require_relative 'media_server'

# # Lint remover
# module Rack
#   class Lint
#     def call(env = nil)
#       @app.call(env)
#     end
#   end
# end

# require 'logger'
# use Rack::CommonLogger, Logger.new('access.log')


use Rainbows::Sendfile
# use Rack::Reloader, 0
# use Rack::ContentLength

run MediaServer
