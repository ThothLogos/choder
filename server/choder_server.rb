# Choder - TCP Chat Server
#
# 20150511 - ThothLogos
#

require 'socket'

class Server

  def initialize(address, port)
    @server = TCPServer.open(address, port)
    @connections = Hash.new
    @rooms = Hash.new
    @clients = Hash.new
    @connections[:server] = @server
    @connections[:rooms] = @rooms
    @connections[:clients] = @clients
    run
  end

  def run
    puts "Server ready."
    loop do
      Thread.start(@server.accept) do |client|
        puts "New thread started, client ID: #{client}"
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
        client.puts "Connection established, logged in as #{username}."

        # Begin listening to connected client
        listen(username, client)
      end
    end.join
  end

  def listen(localuser, client)
    puts "Listening to #{localuser} #{client}"
    loop do
      message = client.gets.chomp
      @connections[:clients].each do |user, client|
        # Broadcast message to everyone except the origin
        if user != localuser
          client.puts "#{localuser.to_s}: #{message}"; end 
      end
    end
  end

end

server = Server.new("localhost", 7680)