package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"clockout/server/internal/hub"
	"clockout/server/internal/protocol"
)

func main() {
	port := flag.Int("port", protocol.DefaultPort, "listen port")
	flag.Parse()
	addr := fmt.Sprintf(":%d", *port)
	h := hub.New()
	if err := h.ListenAndServe(addr); err != nil {
		log.Printf("listen failed: %v", err)
		os.Exit(1)
	}
}
