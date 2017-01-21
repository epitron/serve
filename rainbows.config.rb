# https://bogomips.org/unicorn/examples/unicorn.conf.rb

require 'sendfile'
require "io/splice"

worker_processes 4 # assuming four CPU cores

Rainbows! do
  use :ThreadPool

  worker_connections 20
  copy_stream IO::Splice
end
