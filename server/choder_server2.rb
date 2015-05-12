# Choder - TCP Chat Server 2
#
# 20150512 - ThothLogos
#
# Second stab at TCP server for Choder platform.

require 'socket'

max_read_size = 32  # bytes

# Sets up both ipv4 and ipv6 bindings
Socket.tcp_server_loop(7680) do |conn|
  
  # Silly client authorization
  auth = conn.gets.chomp
  if auth == "choder_test2"
    puts "Verified client."
  else
    puts "Illegal client."
    conn.close
  end

  # Continually return stream data in partial reads up to a maximum chunk size
  begin
    while data = conn.readpartial(max_read_size) do
      puts data
    end
  rescue EOFError # readpartial will produce an exception upon an EOF
  end
  conn.close
end
