# https://bogomips.org/unicorn/examples/unicorn.conf.rb

require 'sendfile'
require "io/splice"

worker_processes 4 # assuming four CPU cores

Rainbows! do
  # use :FiberSpawn
  use :ThreadPool
  # use :RevFiberSpawn

  # use :ThreadSpawn
  # use :EventMachine
  # use :NeverBlock  # using EventMachine

  worker_connections 100
  copy_stream IO::Splice
end
