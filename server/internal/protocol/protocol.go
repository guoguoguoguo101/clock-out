package protocol

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
)

const (
	DefaultPort = 27111
	MaxClients  = 64
	MaxRooms    = 16
	MaxHumans   = 6
	SnapHz      = 15
	TickHz      = 20
	InputHz     = 20
)

const (
	TypeHello      = "hello"
	TypeWelcome    = "welcome"
	TypeCreateRoom = "create_room"
	TypeJoinRoom   = "join_room"
	TypeListRooms  = "list_rooms"
	TypeLeaveRoom  = "leave_room"
	TypeRoomReady  = "room_ready"
	TypeRoomList   = "room_list"
	TypeClaim      = "claim"
	TypeBotSlot    = "bot_slot"
	TypeFillBots   = "fill_bots"
	TypeStart      = "start"
	TypeReset      = "reset"
	TypeError      = "error"
	TypeInput      = "input"
	TypeSnapshot   = "snapshot"
	TypeEvent      = "event"
	TypeLobby      = "lobby"
)

var ErrShort = errors.New("frame too short")

type Message struct {
	Type     string     `json:"type"`
	Peer     int        `json:"peer,omitempty"`
	Code     string     `json:"code,omitempty"`
	Slot     int        `json:"slot,omitempty"`
	Name     string     `json:"name,omitempty"`
	Short    bool       `json:"short,omitempty"`
	Reason   string     `json:"reason,omitempty"`
	Captain  int        `json:"captain,omitempty"`
	DX       float64    `json:"dx,omitempty"`
	DY       float64    `json:"dy,omitempty"`
	Interact bool       `json:"interact,omitempty"`
	Slack    bool       `json:"slack,omitempty"`
	Meeting  bool       `json:"meeting,omitempty"`
	KPI      bool       `json:"kpi,omitempty"`
	Dash     bool       `json:"dash,omitempty"`
	On       bool       `json:"on,omitempty"`
	Rooms    []RoomInfo `json:"rooms,omitempty"`
	Snapshot *Snapshot  `json:"snapshot,omitempty"`
	Event    *Event     `json:"event,omitempty"`
	Lobby    *Lobby     `json:"lobby,omitempty"`
}

type RoomInfo struct {
	Code    string `json:"code"`
	Players int    `json:"players"`
	Phase   string `json:"phase"`
}

type Lobby struct {
	Code     string         `json:"code"`
	Phase    string         `json:"phase"`
	Short    bool           `json:"short"`
	Captain  int            `json:"captain"`
	Slots    map[string]int `json:"slots"`
	Names    map[string]string `json:"names"`
}

type Snapshot struct {
	Phase     string             `json:"phase"`
	Elapsed   float64            `json:"elapsed"`
	Left      float64            `json:"left"`
	Countdown float64            `json:"cd"`
	Actors    []ActorSnap        `json:"actors"`
	Doors     []DoorSnap         `json:"doors"`
	Occupiers map[string]int     `json:"occupiers"`
}

type ActorSnap struct {
	Slot         int     `json:"slot"`
	Peer         int     `json:"peer"`
	Name         string  `json:"name"`
	X            float64 `json:"x"`
	Y            float64 `json:"y"`
	State        int     `json:"state"`
	Hours        float64 `json:"hours"`
	Energy       float64 `json:"energy"`
	Visible      bool    `json:"visible"`
	MeetingCD    float64 `json:"mcd"`
	KPICD        float64 `json:"kcd"`
	DashCD       float64 `json:"dcd"`
	Occupy       string  `json:"occupy"`
	Talk         float64 `json:"talk"`
	Rescue       float64 `json:"rescue"`
	Bike         float64 `json:"bike"`
	Carrying     int     `json:"carrying"`
	CarriedBy    int     `json:"carried_by"`
	FacingX      float64 `json:"facing_x"`
	StandLock    float64 `json:"stand_lock"`
}

type DoorSnap struct {
	ID      string  `json:"id"`
	Closed  bool    `json:"closed"`
	Opening bool    `json:"opening"`
	Left    float64 `json:"open_left"`
}

type Event struct {
	Kind       string         `json:"kind"`
	Slot       int            `json:"slot"`
	BySlot     int            `json:"by_slot"`
	Repeat     bool           `json:"repeat,omitempty"`
	AddHours   float64        `json:"add_hours,omitempty"`
	On         bool           `json:"on,omitempty"`
	Passenger  int            `json:"passenger"`
	X          float64        `json:"x,omitempty"`
	Y          float64        `json:"y,omitempty"`
	Interrupted bool          `json:"interrupted,omitempty"`
	Facing     float64        `json:"facing,omitempty"`
	Result     map[string]any `json:"result,omitempty"`
}

func Encode(msg Message) ([]byte, error) {
	body, err := json.Marshal(msg)
	if err != nil {
		return nil, err
	}
	out := make([]byte, 4+len(body))
	binary.BigEndian.PutUint32(out, uint32(len(body)))
	copy(out[4:], body)
	return out, nil
}

func Decode(raw []byte) (Message, error) {
	var msg Message
	if len(raw) < 4 {
		return msg, ErrShort
	}
	n := int(binary.BigEndian.Uint32(raw[:4]))
	if n < 0 || 4+n > len(raw) {
		return msg, fmt.Errorf("bad frame length %d (have %d)", n, len(raw))
	}
	if err := json.Unmarshal(raw[4:4+n], &msg); err != nil {
		return msg, err
	}
	return msg, nil
}
