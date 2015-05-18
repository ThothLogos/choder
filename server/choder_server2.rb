# Choder - TCP Chat Server 2
#
# 20150512 - ThothLogos
#
# This implementation is a single-threaded event-based server. Concurrency
# is handled with an object for each connection rather than a thread or process.


require 'socket'

module ChoderServer

  CRLF = "\r\n"

  class Server

    # Maximum chunk size in bytes before the server will force a return
    MAX_READ_SIZE = 1024 * 4

    # One instance of the server listens for client request on a @control_socket
    def initialize(port)
      @control_socket = TCPServer.new(port)
      # What to do upon Ctrl-C
      trap(:INT) do
        puts "\nExiting..."
        exit 130
      end
      @@clients = Hash.new
      puts "Choder server established on port #{port}."
    end

    # Start listen/read/write loop
    def run
      
      ##~ ~ ~ Debug ~ ~ ~##
      iteration = 0
      
      loop do
        
        ##~ ~ ~ Debug ~ ~ ~##
        iteration += 1
        print "\n-= Iteration: #{iteration}\n"

        # Every connection
        to_read = @@clients.values.select(&:read_ready?).map(&:client)
        to_write = @@clients.values.select(&:write_ready?).map(&:client)
        
        ##~ ~ ~ Debug ~ ~ ~##
        puts "Reads: " + to_read.to_s
        puts "Writes: " + to_write.to_s

        # Locate the IO object for each connection and check for read/write
        # readiness, monitor @control_socket for new incoming clients
        readables, writables = IO.select(to_read + [@control_socket], to_write)
        
        ##~ ~ ~ Debug ~ ~ ~##
        puts "Readables: " + readables.to_s
        puts "Writables: "
        writables.each do |s|
          c = @@clients.key(@@clients[s.fileno]) 
          puts "Return to client #{c} => " + @@clients[s.fileno].response.to_s
        end

        # For each socket ready to be read
        readables.each do |socket|
          # If @control_socket shows up as readable, there's a new incoming client
          if socket == @control_socket
            # Accept the new client and build a unique Connection object for it
            client = @control_socket.accept
            connection = Connection.new(client)
            puts "New client connection at #{client.fileno} #{client} #{connection}."
            connection.respond("Connected to Choder server.")
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
  class Connection < Server
    attr_reader :client
    attr_reader :response
    
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

    def read_ready?
      true # Always listen
    end

    def write_ready?
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
        return "Server echo'd: #{args}"
      when 'PORT' # Establish a dynamic range data port
        pieces = args.split(',')
        address = pieces[0..3].join('.')
        port = Integer(pieces[4]) * 256 + Integer(pieces[5])
        @data_socket = TCPSocket.new(address, port)
        return "Data connection established on port #{port}."
      when 'LIST' # List available files on server
        connection.respond "Available files on this server: "
        file_list = Dir.entries(Dir.pwd).join(CRLF)
        @data_socket.write(file_list)
        @data_socket.close
        return "End file list."
      when 'FILE' # Request file from server
        if File.file?(Dir.pwd + args) # Check if the target exists and is a file
          file = File.open(File.join(Dir.pwd, args), 'r')
          connection.respond "Opening data stream, sending #{file.size} bytes."
          bytes = IO.copy_stream(file, @data_socket)
          @data_socket.close
          return "Closing data stream, sent #{bytes} bytes."
        else
          return "Unable to locate requested file: #{args}"
        end
      else
        return "Unrecognized command: #{cmd}."
      end # case
    end # handle()
  end # EventHandler

end # ChoderServer


# Start server
server = ChoderServer::Server.new(7680)
server.run