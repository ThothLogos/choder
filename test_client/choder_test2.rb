# Choder - TCP Chat Test Client 2
#
# 20150512 - ThothLogos
#
# Test client for second attempt at TCP platform.

require 'socket'

module ChoderClient

  CRLF = "\r\n"

  class Client

    def initialize(address = "localhost", port = "7680")
      @connection = Socket.tcp(address, port)
    end

    def run
      running = true
      while running
        puts "Enter message to server (x or q to exit): "
        input = gets.chomp
        if input == "x" || input == "q"
          running = false
        elsif !input.empty?
          input += CRLF
          @connection.write input
        end  
      end
      @connection.close
    end # run()

  end #Client

end # ChoderClient

client = ChoderClient::Client.new()
client.run