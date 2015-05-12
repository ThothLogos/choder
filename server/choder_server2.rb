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

module Choder

  class Server

    # Maximum chunk size, in bytes, before the server will force a return
    MAX_READ_SIZE = 1024 * 4
    CRLF = "\r\n"
    
    # One instance of the server operates on a control port, specific
    # data instances between client/server will be handled on the fly
    # through an event system and separate dynamic ports
    def initialize(port)
      @control_socket = TCPServer.new(port)
      # What to do upon Ctrl-C
      trap(:INT) do
        puts "Exiting..."
        exit 130
      end
    end

    def respond(response)
      @client.write(response)
      @client.write(CRLF)
    end

    # Each connection will have its own EventHandler instance
    class EventHandler
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
          return "Not yet implemented"
        when 'FIND' # Check if user is online
          return "Not yet implemented."
        when 'MSG'  # Send message to user
          return "Not yet implemented."
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


    # Each incoming client connection will be encapsulated into its own object
    class Connection
      attr_reader :client
      
      def initialize(client)
        @client = client
        @request, @response = "", ""
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
          @request = "" # Clear the request
        end
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

    def run
      @handles = Hash.new

      loop do
        # Check each active client connection for available read/write traffic
        to_read = @handles.values.select(&:monitor_for_reading?).map(&:client)
        to_write = @handles.values.select(&:monitor_for_writing?).map(&:client)

        # Locate the IO object for each connection with a read/write ready, also
        # monitor @control_socket for new incoming clients
        readables, writables = IO.select(to_read + [@control_socket], to_write)

        # For each socket ready to be read
        readables.each do |socket|
          # If the @control_socket is readable, it means there's a new client
          if socket == @control_socket
            # Accept the new client and build a new Connection for it
            client = @control_socket.accept
            connection = Connection.new(client)
            @handles[client.fileno] = connection # Add connection to client table
          else # Ordinary data request from existing client
            connection = @handles[socket.fileno] # Locate the client's connection
            begin # Read sequence
              data = socket.read_nonblock(MAX_READ_SIZE)
              connection.on_data(data)
            rescue Errno::EAGAIN
            rescue EOFError # Client dropped connection
              @handles.delete(socket.fileno) # Remove from active client table
            end
          end
        end

        writables.each do |socket|
          connection = @handles[socket.filno]
          connection.on_writable
        end

      end # loop
    end # run()
  end # Server
end # Choder

server = Choder::Server.new(7680)
server.run