# Choder - TCP Chat Server
#
# 20150511 - ThothLogos
#

require 'socket'

class Server

  def initialize(address, port)
    @server = TCPServer.open(address, port)
    @connections = {}
    @rooms = {}
    @clients = {}
  end

  def run
    loop do
      Thread.start do |client|
        
        # The first input coming from the client will be the username
        username = client.gets.chomp.to_sym
        
        # Scan through each user that is already logged in, check for duplicate
        # username or client ID
        @connections[:clients].each do |existing_name, existing_client|
          if username == existing_name || client == existing_client
            client.puts "Sorry, this user is already logged in."
            Thread.kill self; end # If found, kill this login thread 
        end
        
        # Else, successful login, add user to client table
        @connections[:clients][username] = client
        client.puts "Connection established."

        # Server side log
        puts "#{username} connected, client ID: #{client}"
      end
    end
  end

end

server = Server.new("localhost", 7680)
server.run