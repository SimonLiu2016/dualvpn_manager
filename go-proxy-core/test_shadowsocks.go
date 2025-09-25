package main

import (
	"fmt"
	"net"
	"time"

	"github.com/shadowsocks/go-shadowsocks2/core"
	"github.com/shadowsocks/go-shadowsocks2/socks"
)

func main() {
	cipher, err := core.PickCipher("CHACHA20-IETF-POLY1305", nil, "ef18df75-d207-38ca-90ea-97884c4a9397")
	if err != nil {
		fmt.Printf("Error creating cipher: %v\n", err)
		return
	}

	conn, err := net.DialTimeout("tcp", "cncm.hushitanke.top:50016", 5*time.Second)
	if err != nil {
		fmt.Printf("Error connecting to server: %v\n", err)
		return
	}
	defer conn.Close()

	conn = cipher.StreamConn(conn)

	addr := socks.ParseAddr("www.google.com:443")
	if addr == nil {
		fmt.Printf("Error: failed to parse address\n")
		return
	}

	_, err = conn.Write(addr)
	if err != nil {
		fmt.Printf("Error writing address: %v\n", err)
		return
	}

	fmt.Printf("Connection successful\n")
}
