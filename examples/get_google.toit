import net
import net.x509 as net
import http
import tls
import certificate_roots

main:
  network_interface := net.open

  host := "www.google.com"
  tcp := network_interface.tcp_connect host 443

  socket := tls.Socket.client tcp
    --server_name=host
    --root_certificates=[certificate_roots.GLOBALSIGN_ROOT_CA]

  connection := http.Connection socket host
  request := connection.new_request "GET" "/"
  response := request.send

  bytes := 0
  while data := response.read:
    bytes += data.size

  print "Read $bytes bytes from https://$host/"
