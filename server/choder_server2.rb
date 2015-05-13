# Choder - TCP Chat Server 2
#
# 20150512 - ThothLogos
#
# Second stab at TCP server for Choder platform.
#
# This implementation is a single-threaded event-based server. Concurrency
# is handled with an object for each connection rather than a thread or process.
#
# For simplicity/immediacy, initial API commands copied from FTP.

require 'socket'

module ChoderServer

  CRLF = "\r\n"

  class Server

    # Maximum chunk size, in bytes, before the server will force a return
    MAX_READ_SIZE = 1024 * 4

    # One instance of the server operates on a control port, specific
    # data instances between client/server will be handled on the fly
    # through an event system and separate dynamic ports
    def initialize(port)
      @control_socket = TCPServer.new(port)
      # What to do upon Ctrl-C
      trap(:INT) do
        puts "\nExiting..."
        exit 130
      end
      # Key/value table to hold client connection IDs and the connection itself
      @@clients = Hash.new
      puts "Choder server established on port #{port}."
    end

    # Primary program process containing the server's listening loop
    def run
      iteration = 0
      loop do
        iteration += 1
        print "\n-= Iteration: #{iteration}\n"
        # Check each active client connection for available read/write traffic
        to_read = @@clients.values.select(&:monitor_for_reading?).map(&:client)
        to_write = @@clients.values.select(&:monitor_for_writing?).map(&:client)
        puts "Reads: " + to_read.to_s unless to_read == nil
        puts "Writes: " + to_write.to_s unless to_write == nil
        # Locate the IO object for each connection and check for read/write
        # readiness, monitor @control_socket for new incoming clients
        readables, writables = IO.select(to_read + [@control_socket], to_write)
        puts "Readables: " + readables.to_s
        puts "Writables: " + writables.to_s
        # For each socket ready to be read
        readables.each do |socket|
          # If @control_socket shows up as readable, there's a new incoming client
          if socket == @control_socket
            # Accept the new client and build a unique Connection object for it
            client = @control_socket.accept
            connection = Connection.new(client)
            puts "New client connection at #{client.fileno} #{client} #{connection}."
            @@clients[client.fileno] = connection # Add connection to client table
          else # Ordinary data request from existing client
            connection = @@clients[socket.fileno] # Locate the client's connection
            begin # Read sequence
              data = socket.read_nonblock(MAX_READ_SIZE)
              puts "Client #{connection} request: #{data.to_s}"
              connection.on_data(data)
            rescue Errno::EAGAIN
            rescue EOFError # Client dropped connection
              drop_client(socket) # Remove from active client table
            rescue Errno::ECONNRESET # Client closed connection
              drop_client(socket)
            end
          end
        end # readables

        writables.each do |socket|
          connection = @@clients[socket.fileno]
          connection.on_writable
        end

      end # loop
    end # run()

    def clients
      @@clients
    end

    def respond(response)
      @client.write(response)
      @client.write(CRLF)
    end

    def drop_client(socket)
      @@clients.delete(socket.fileno)
      puts "Client #{socket.fileno} #{socket} removed from active connections."
    end
  end # Server


  # Each incoming client connection will be encapsulated into its own object
  class Connection
    attr_reader :client
    
    def initialize(client)
      @client = client
      @request, @response = "", ""
      # Each connection has its own instance of the EventHandler
      @handler = EventHandler.new(self)
      @response =  "Connection to Choder esablished." + CRLF
      on_writable
    end

    def on_data(data)
      @request << data
      # Is the incoming data a complete request?
      if @request.end_with?(CRLF)
        # Handle the request and package a response
        @response = @handler.handle(@request) + CRLF
      else
        puts "Invalid request from client."
      end
      @request = "" # Clear the request
    end

    def on_writable
      bytes = client.write_nonblock(@response)
      # If partial write, remove the portion that was already transmitted
      @response.slice!(0, bytes)
    end

    def monitor_for_reading?
      true # Always listen
    end

    def monitor_for_writing?
      !(@response.empty?) # Only prep for writing if there's a response ready
    end
  end # Connection

  
  # Each connection will have its own EventHandler instance
  class EventHandler < Server
    attr_reader :connection

    def initialize(connection)
      @connection = connection
    end

    # The primary method for handling an incoming request
    def handle(request)
      # Parse first 4 characters for protocol function
      cmd = request[0..3].strip.upcase
      # Remaining data is request arguments
      args = request[4..-1].strip

      case cmd
      when 'USER' # Incoming username information for login
        return "You are logged in as #{args}."
      when 'INFO' # Server identifcation
        return "Choder React Server 0.1a"
      when 'WHO'  # List all users online
        puts clients
        return clients.to_s
      when 'FIND' # Check if user is online
        return "Not yet implemented."
      when 'MSG'  # Send message to user
        return "Not yet implemented."
      when 'ECHO' # Send message to server
        puts args
        return "Echo: #{args}"
      when 'PORT' # Establish a dynamic range data port
        # Strip values between commas
        pieces = args.split(',')
        # Rebuild as an IPv4 address
        address = pieces[0..3].join('.')
        # Assemble a dynamic port
        port = Integer(pieces[4]) * 256 + Integer(pieces[5])
        # Bind a new socket to this port
        @data_socket = TCPSocket.new(address, port)
        return "Data connection established on port #{port}."
      when 'LIST' # List available files on server
        connection.respond "Available files on this server: "
        file_list = Dir.entries(Dir.pwd).join(CRLF)
        @data_socket.write(file_list)
        @data_socket.close
        return "End file list."
      when 'FILE' # Request file from server
        # Incoming function arguments should contain filename
        file = File.open(File.join(Dir.pwd, args), 'r')
        connection.respond "Opening data stream, sending #{file.size} bytes."
        bytes = IO.copy_stream(file, @data_socket)
        @data_socket.close
        return "Closing data stream, sent #{bytes} bytes."
      else
        return "Unrecognized command: #{cmd}."
      end # case
    end # handle()
  end # EventHandler

end # ChoderServer


# Start server
server = ChoderServer::Server.new(7680)
server.run