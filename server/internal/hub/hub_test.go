package hub

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"clockout/server/internal/protocol"
)

func dial(t *testing.T, url string) *websocket.Conn {
	t.Helper()
	wsURL := "ws" + strings.TrimPrefix(url, "http")
	c, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func send(t *testing.T, c *websocket.Conn, msg protocol.Message) {
	t.Helper()
	buf, err := protocol.Encode(msg)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.WriteMessage(websocket.BinaryMessage, buf); err != nil {
		t.Fatal(err)
	}
}

func recv(t *testing.T, c *websocket.Conn) protocol.Message {
	t.Helper()
	_ = c.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, raw, err := c.ReadMessage()
	if err != nil {
		t.Fatal(err)
	}
	msg, err := protocol.Decode(raw)
	if err != nil {
		t.Fatal(err)
	}
	return msg
}

func recvType(t *testing.T, c *websocket.Conn, typ string) protocol.Message {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		_ = c.SetReadDeadline(deadline)
		_, raw, err := c.ReadMessage()
		if err != nil {
			t.Fatal(err)
		}
		msg, err := protocol.Decode(raw)
		if err != nil {
			t.Fatal(err)
		}
		if msg.Type == typ {
			return msg
		}
	}
	t.Fatalf("timeout waiting for %s", typ)
	return protocol.Message{}
}

func TestTwoRoomsDoNotShareSnapshots(t *testing.T) {
	h := New()
	go h.loop()
	mux := http.NewServeMux()
	mux.HandleFunc("/", h.handleWS)
	srv := httptest.NewServer(mux)
	defer srv.Close()

	a := dial(t, srv.URL)
	defer a.Close()
	b := dial(t, srv.URL)
	defer b.Close()
	c := dial(t, srv.URL)
	defer c.Close()

	send(t, a, protocol.Message{Type: protocol.TypeHello})
	send(t, b, protocol.Message{Type: protocol.TypeHello})
	send(t, c, protocol.Message{Type: protocol.TypeHello})
	recvType(t, a, protocol.TypeWelcome)
	recvType(t, b, protocol.TypeWelcome)
	recvType(t, c, protocol.TypeWelcome)

	send(t, a, protocol.Message{Type: protocol.TypeCreateRoom})
	ra := recvType(t, a, protocol.TypeRoomReady)
	send(t, b, protocol.Message{Type: protocol.TypeJoinRoom, Code: ra.Code})
	recvType(t, b, protocol.TypeRoomReady)

	send(t, c, protocol.Message{Type: protocol.TypeCreateRoom})
	rc := recvType(t, c, protocol.TypeRoomReady)
	if rc.Code == ra.Code {
		t.Fatal("same room code")
	}

	send(t, a, protocol.Message{Type: protocol.TypeClaim, Slot: 0, Name: "Boss"})
	send(t, a, protocol.Message{Type: protocol.TypeStart, Short: true})
	recvType(t, a, protocol.TypeLobby)

	_ = c.SetReadDeadline(time.Now().Add(400 * time.Millisecond))
	for {
		_, raw, err := c.ReadMessage()
		if err != nil {
			break
		}
		msg, _ := protocol.Decode(raw)
		if msg.Type == protocol.TypeSnapshot {
			t.Fatal("room C received snapshot from another match")
		}
	}
}
