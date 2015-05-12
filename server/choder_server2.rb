# Choder - TCP Chat Server 2
#
# 20150512 - ThothLogos
#
# Second stab at TCP server for Choder platform.

require 'socket'

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

  # Continually return stream data in 1kB chunks, without a read length
  # the server would only return the read when an EOF was reached.
  while data = conn.read(1024) do
    puts data
  end
  
  conn.close
end
