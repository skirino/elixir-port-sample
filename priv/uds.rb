#!/usr/bin/env ruby

require 'socket'
require 'fileutils'

raise if ARGV.size != 2

SOCK_PATH = ARGV[0]
File.unlink SOCK_PATH if File.exist? SOCK_PATH
PARENT_PID = ARGV[1].to_i

STDIN .sync = true
STDOUT.sync = true
BUF_LEN = 4096

class UnixDomainSocketServer
  def initialize(serv)
    @serv = serv
    check_exit
  end

  def accept_sock
    @serv.accept_nonblock
  rescue IO::WaitReadable, Errno::EINTR
    check_exit while IO.select([@serv], [], [], 1).nil?
    retry
  end

  def handle_client_session(sock)
    bytes = read_exact_from_socket(sock)
    return if bytes.empty?
    ret = communicate_with_erl(bytes)
    sock.send(ret, 0)
  end

  def read_exact(&block)
    ret = ''
    begin
      len = ret.size
      ret << yield
    end while BUF_LEN <= ret.size - len
    ret
  rescue => e
    ret
  end
  def read_exact_from_stdin
    read_exact { STDIN.readpartial(BUF_LEN) }
  end
  def read_exact_from_socket(sock)
    read_exact { sock.recv_nonblock(BUF_LEN) }
  end

  def communicate_with_erl(bytes)
    STDOUT.write [bytes.size].pack('N') + bytes
    read_exact_from_stdin[4 .. -1]
  end

  def check_exit
    raise if !File.exist?(SOCK_PATH)
    Process.kill(0, PARENT_PID) # raise if the parent not found
  end

  def handle_one_request
    sock = accept_sock
    handle_client_session(sock)
  ensure
    sock.close if sock
  end
end

begin
  UNIXServer.open(SOCK_PATH) do |serv|
    s = UnixDomainSocketServer.new(serv)
    loop { s.handle_one_request }
  end
rescue => e
  File.write('/tmp/elixir_uds_rb.log', [e.class, e.message, e.backtrace])
ensure
  FileUtils.rm_f SOCK_PATH
end
