# Choder - TCP Chat Test Client
#
# 20150511 - ThothLogos
#

require 'socket'

class Client

  def initialize(address, port)
    @server = TCPSocket.open(address, port)
    @request = nil
    @response = nil
    listen
    send
    @request.join
    @response.join
  end

  def listen
    @response = Thread.new do
      loop do
        message = @server.gets.chomp
        puts "#{message}"
      end
    end
  end

  def send
    puts "Enter username: "
    @request = Thread.new do
      loop do
        message = $stdin.gets.chomp
        @server.puts(message)
      end
    end
  end

end

Client.new("localhost", 7680)