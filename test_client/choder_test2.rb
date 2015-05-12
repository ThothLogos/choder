# Choder - TCP Chat Test Client 2
#
# 20150512 - ThothLogos
#
# Test client for second attempt at TCP platform.

require 'socket'

# Open TCP connection, grab the connection
Socket.tcp('localhost', 7680) do |connection|
  
  # Send client version to server
  connection.write "choder_test2\n"
  
  running = true

  while running
    puts "Enter message to server (x or q to exit): "
    input = gets.chomp

    if input == "x" || input == "q"
      running = false
    else
      connection.write input
    end    
  end

  connection.close
end

