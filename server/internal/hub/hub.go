package hub

import (
	"log"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"

	"clockout/server/internal/lobby"
	"clockout/server/internal/protocol"
	"clockout/server/internal/sim"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Client struct {
	Peer int
	conn *websocket.Conn
	send chan []byte
	hub  *Hub
}

type Hub struct {
	lobby   *lobby.Lobby
	mu      sync.Mutex
	clients map[int]*Client
	nextID  int
}

func New() *Hub {
	return &Hub{
		lobby:   lobby.New(),
		clients: map[int]*Client{},
		nextID:  2,
	}
}

func (h *Hub) ListenAndServe(addr string) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/", h.handleWS)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	go h.loop()
	log.Printf("clock-out server listening on %s dedicated=true", addr)
	return http.Serve(ln, mux)
}

func (h *Hub) handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	h.mu.Lock()
	if len(h.clients) >= protocol.MaxClients {
		h.mu.Unlock()
		_ = conn.Close()
		return
	}
	id := h.nextID
	h.nextID++
	c := &Client{Peer: id, conn: conn, send: make(chan []byte, 32), hub: h}
	h.clients[id] = c
	h.mu.Unlock()
	go c.writePump()
	c.readPump()
}

func (c *Client) readPump() {
	defer c.hub.drop(c)
	c.conn.SetReadLimit(1 << 16)
	_ = c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})
	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		msg, err := protocol.Decode(raw)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: "消息解析失败"})
			continue
		}
		c.hub.dispatch(c, msg)
	}
}

func (c *Client) writePump() {
	tick := time.NewTicker(20 * time.Second)
	defer func() {
		tick.Stop()
		_ = c.conn.Close()
	}()
	for {
		select {
		case buf, ok := <-c.send:
			if !ok {
				return
			}
			_ = c.conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
			if err := c.conn.WriteMessage(websocket.BinaryMessage, buf); err != nil {
				return
			}
		case <-tick.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(8 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *Client) sendMsg(msg protocol.Message) {
	buf, err := protocol.Encode(msg)
	if err != nil {
		return
	}
	select {
	case c.send <- buf:
	default:
	}
}

func (h *Hub) drop(c *Client) {
	h.mu.Lock()
	delete(h.clients, c.Peer)
	h.mu.Unlock()
	closeSend(c)
	room, _, destroyed := h.lobby.Disconnect(c.Peer)
	if room != nil && !destroyed {
		h.broadcastLobby(room)
	}
}

func closeSend(c *Client) {
	defer func() { recover() }()
	close(c.send)
}

func (h *Hub) dispatch(c *Client, msg protocol.Message) {
	switch msg.Type {
	case protocol.TypeHello:
		c.sendMsg(protocol.Message{Type: protocol.TypeWelcome, Peer: c.Peer})
		c.sendMsg(protocol.Message{Type: protocol.TypeRoomList, Rooms: h.lobby.List()})
	case protocol.TypeCreateRoom:
		r, err := h.lobby.Create(c.Peer)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		c.sendMsg(protocol.Message{Type: protocol.TypeRoomReady, Code: r.Code, Captain: r.Captain, Peer: c.Peer})
		h.broadcastLobby(r)
		h.broadcastList()
	case protocol.TypeJoinRoom:
		r, err := h.lobby.Join(c.Peer, msg.Code)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		c.sendMsg(protocol.Message{Type: protocol.TypeRoomReady, Code: r.Code, Captain: r.Captain, Peer: c.Peer})
		h.broadcastLobby(r)
		h.broadcastList()
	case protocol.TypeListRooms:
		c.sendMsg(protocol.Message{Type: protocol.TypeRoomList, Rooms: h.lobby.List()})
	case protocol.TypeLeaveRoom:
		r := h.lobby.Leave(c.Peer)
		c.sendMsg(protocol.Message{Type: protocol.TypeRoomList, Rooms: h.lobby.List()})
		if r != nil {
			h.broadcastLobby(r)
		}
		h.broadcastList()
	case protocol.TypeClaim:
		r, err := h.lobby.Claim(c.Peer, msg.Slot, msg.Name)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		h.broadcastLobby(r)
	case protocol.TypeBotSlot:
		r, err := h.lobby.SetBot(c.Peer, msg.Slot, msg.On)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		h.broadcastLobby(r)
	case protocol.TypeFillBots:
		r, err := h.lobby.FillBots(c.Peer)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		h.broadcastLobby(r)
	case protocol.TypeStart:
		r, err := h.lobby.Start(c.Peer, msg.Short)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		h.broadcastLobby(r)
		h.broadcastList()
	case protocol.TypeReset:
		r, err := h.lobby.Reset(c.Peer)
		if err != nil {
			c.sendMsg(protocol.Message{Type: protocol.TypeError, Reason: err.Error()})
			return
		}
		h.broadcastLobby(r)
		h.broadcastList()
	case protocol.TypeInput:
		h.lobby.ApplyInput(c.Peer, sim.Input{
			DX: msg.DX, DY: msg.DY, Interact: msg.Interact, Slack: msg.Slack,
			Meeting: msg.Meeting, KPI: msg.KPI, Dash: msg.Dash,
			Incident: msg.Incident, Blame: msg.Blame,
		})
	}
}

func (h *Hub) loop() {
	tick := time.NewTicker(time.Second / protocol.TickHz)
	snap := time.NewTicker(time.Second / protocol.SnapHz)
	defer tick.Stop()
	defer snap.Stop()
	dt := 1.0 / float64(protocol.TickHz)
	for {
		select {
		case <-tick.C:
			h.lobby.ForEach(func(r *lobby.Room) {
				if r.Match.Phase == "countdown" || r.Match.Playing {
					r.Match.Tick(dt)
				}
			})
		case <-snap.C:
			type job struct {
				members []int
				msgs    []protocol.Message
			}
			var jobs []job
			h.lobby.ForEach(func(r *lobby.Room) {
				if r.Match.Phase == "lobby" {
					return
				}
				j := job{members: r.HumanIDs()}
				j.msgs = append(j.msgs, protocol.Message{Type: protocol.TypeSnapshot, Snapshot: ptrSnap(r.Match.Snapshot())})
				for _, ev := range r.Match.DrainEvents() {
					e := ev
					j.msgs = append(j.msgs, protocol.Message{Type: protocol.TypeEvent, Event: &e})
				}
				if r.Match.Phase == "result" {
					st := r.Match.LobbyState(r.Code, r.Captain)
					j.msgs = append(j.msgs, protocol.Message{Type: protocol.TypeLobby, Lobby: &st, Code: r.Code, Captain: r.Captain})
				}
				jobs = append(jobs, j)
			})
			for _, j := range jobs {
				for _, msg := range j.msgs {
					h.sendTo(j.members, msg)
				}
			}
		}
	}
}

func ptrSnap(s protocol.Snapshot) *protocol.Snapshot { return &s }

func (h *Hub) broadcastLobby(r *lobby.Room) {
	if r == nil {
		return
	}
	st := r.Match.LobbyState(r.Code, r.Captain)
	h.broadcast(r, protocol.Message{Type: protocol.TypeLobby, Lobby: &st, Code: r.Code, Captain: r.Captain})
}

func (h *Hub) broadcastList() {
	list := h.lobby.List()
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, c := range h.clients {
		c.sendMsg(protocol.Message{Type: protocol.TypeRoomList, Rooms: list})
	}
}

func (h *Hub) broadcast(r *lobby.Room, msg protocol.Message) {
	h.sendTo(r.HumanIDs(), msg)
}

func (h *Hub) sendTo(members []int, msg protocol.Message) {
	buf, err := protocol.Encode(msg)
	if err != nil {
		return
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, peer := range members {
		c := h.clients[peer]
		if c == nil {
			continue
		}
		select {
		case c.send <- buf:
		default:
		}
	}
}

func (h *Hub) Lobby() *lobby.Lobby { return h.lobby }
