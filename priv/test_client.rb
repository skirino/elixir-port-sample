#!/usr/bin/env ruby

require 'socket'

SOCK_PATH = ARGV[0]
MESSAGE   = ARGV[1]

UNIXSocket.open SOCK_PATH do |s|
  s.write MESSAGE
  puts s.recv 8192
end
