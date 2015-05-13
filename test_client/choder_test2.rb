# Choder - TCP Chat Test Client 2
#
# 20150512 - ThothLogos
#
# Test client for second attempt at TCP platform.

require 'socket'

CRLF = "\r\n"

# Open TCP connection, grab the connection
Socket.tcp('localhost', 7680) do |connection|
  
  running = true

  while running
    puts "Enter message to server (x or q to exit): "
    input = gets.chomp

    if input == "x" || input == "q"
      running = false
    else
      input += CRLF
      connection.write input
    end    
  end

  connection.close
end