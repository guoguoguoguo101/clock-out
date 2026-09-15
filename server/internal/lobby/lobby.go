package lobby

import (
	"crypto/rand"
	"errors"
	"strings"
	"sync"

	"clockout/server/internal/protocol"
	"clockout/server/internal/sim"
)

var (
	ErrRoomLimit   = errors.New("房间已满，稍后再开")
	ErrAlreadyIn   = errors.New("已在其他房间")
	ErrBadCode     = errors.New("房间码无效")
	ErrRoomFull    = errors.New("这间房人满了")
	ErrInProgress  = errors.New("对局进行中，结束后再进")
	ErrNotInRoom   = errors.New("你不在房间里")
	ErrNotCaptain  = errors.New("只有主管能这样操作")
	ErrBadSlot     = errors.New("这个位子有人了")
)

const codeAlphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

type Room struct {
	Code    string
	Captain int
	Members map[int]bool
	Match   *sim.Match
}

func (r *Room) HumanIDs() []int {
	var ids []int
	for id := range r.Members {
		ids = append(ids, id)
	}
	return ids
}

type Lobby struct {
	mu       sync.Mutex
	rooms    map[string]*Room
	peerRoom map[int]string
}

func New() *Lobby {
	return &Lobby{
		rooms:    map[string]*Room{},
		peerRoom: map[int]string{},
	}
}

func (l *Lobby) Create(peer int) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if _, ok := l.peerRoom[peer]; ok {
		return nil, ErrAlreadyIn
	}
	if len(l.rooms) >= protocol.MaxRooms {
		return nil, ErrRoomLimit
	}
	code := l.uniqueCode()
	r := &Room{
		Code:    code,
		Captain: peer,
		Members: map[int]bool{peer: true},
		Match:   sim.NewMatch(),
	}
	l.rooms[code] = r
	l.peerRoom[peer] = code
	return r, nil
}

func (l *Lobby) Join(peer int, code string) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	code = strings.ToUpper(strings.TrimSpace(code))
	if cur, ok := l.peerRoom[peer]; ok {
		if cur == code {
			return l.rooms[code], nil
		}
		return nil, ErrAlreadyIn
	}
	r := l.rooms[code]
	if r == nil {
		return nil, ErrBadCode
	}
	if r.Match.Phase != "lobby" {
		return nil, ErrInProgress
	}
	if len(r.Members) >= protocol.MaxHumans {
		return nil, ErrRoomFull
	}
	r.Members[peer] = true
	l.peerRoom[peer] = code
	return r, nil
}

func (l *Lobby) Leave(peer int) *Room {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.leaveLocked(peer)
}

func (l *Lobby) Disconnect(peer int) (room *Room, convertedSlot int, destroyed bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	code := l.peerRoom[peer]
	if code == "" {
		return nil, -1, false
	}
	r := l.rooms[code]
	if r == nil {
		delete(l.peerRoom, peer)
		return nil, -1, false
	}
	convertedSlot = -1
	if r.Match.Phase != "lobby" {
		for s, p := range r.Match.Slots {
			if p == peer {
				r.Match.ConvertToBot(s)
				convertedSlot = s
			}
		}
	} else {
		for s, p := range r.Match.Slots {
			if p == peer {
				r.Match.Slots[s] = -1
			}
		}
	}
	delete(r.Members, peer)
	delete(l.peerRoom, peer)
	if r.Captain == peer {
		r.Captain = minPeer(r.Members)
	}
	if len(r.Members) == 0 || (r.Match.Phase != "lobby" && r.Match.HumanCount() == 0) {
		delete(l.rooms, code)
		return r, convertedSlot, true
	}
	return r, convertedSlot, false
}

func (l *Lobby) leaveLocked(peer int) *Room {
	code := l.peerRoom[peer]
	if code == "" {
		return nil
	}
	r := l.rooms[code]
	if r == nil {
		delete(l.peerRoom, peer)
		return nil
	}
	if r.Match.Phase != "lobby" {
		for s, p := range r.Match.Slots {
			if p == peer {
				r.Match.ConvertToBot(s)
			}
		}
	} else {
		for s, p := range r.Match.Slots {
			if p == peer {
				r.Match.Slots[s] = -1
			}
		}
	}
	delete(r.Members, peer)
	delete(l.peerRoom, peer)
	if r.Captain == peer {
		r.Captain = minPeer(r.Members)
	}
	if len(r.Members) == 0 || (r.Match.Phase != "lobby" && r.Match.HumanCount() == 0) {
		delete(l.rooms, code)
		return nil
	}
	return r
}

func (l *Lobby) RoomOf(peer int) *Room {
	l.mu.Lock()
	defer l.mu.Unlock()
	code := l.peerRoom[peer]
	if code == "" {
		return nil
	}
	return l.rooms[code]
}

func (l *Lobby) List() []protocol.RoomInfo {
	l.mu.Lock()
	defer l.mu.Unlock()
	out := make([]protocol.RoomInfo, 0, len(l.rooms))
	for _, r := range l.rooms {
		out = append(out, protocol.RoomInfo{
			Code:    r.Code,
			Players: len(r.Members),
			Phase:   r.Match.Phase,
		})
	}
	return out
}

func (l *Lobby) Claim(peer, slot int, name string) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.roomOfLocked(peer)
	if r == nil {
		return nil, ErrNotInRoom
	}
	if !r.Match.Claim(peer, slot, name) {
		return r, ErrBadSlot
	}
	return r, nil
}

func (l *Lobby) SetBot(peer, slot int, on bool) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.roomOfLocked(peer)
	if r == nil {
		return nil, ErrNotInRoom
	}
	if !r.Match.SetBot(slot, on) {
		return r, ErrBadSlot
	}
	return r, nil
}

func (l *Lobby) FillBots(peer int) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.roomOfLocked(peer)
	if r == nil {
		return nil, ErrNotInRoom
	}
	r.Match.FillEmptyBots()
	return r, nil
}

func (l *Lobby) Start(peer int, short bool) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.roomOfLocked(peer)
	if r == nil {
		return nil, ErrNotInRoom
	}
	if r.Captain != peer {
		return r, ErrNotCaptain
	}
	if !r.Match.Start(short, false) {
		return r, errors.New("现在不能开局")
	}
	return r, nil
}

func (l *Lobby) Reset(peer int) (*Room, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.roomOfLocked(peer)
	if r == nil {
		return nil, ErrNotInRoom
	}
	if r.Captain != peer {
		return r, ErrNotCaptain
	}
	r.Match.ResetLobby()
	return r, nil
}

func (l *Lobby) ForEach(fn func(*Room)) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, r := range l.rooms {
		fn(r)
	}
}

func (l *Lobby) ApplyInput(peer int, in sim.Input) {
	l.mu.Lock()
	defer l.mu.Unlock()
	r := l.roomOfLocked(peer)
	if r != nil {
		r.Match.ApplyInput(peer, in)
	}
}

func (l *Lobby) roomOfLocked(peer int) *Room {
	code := l.peerRoom[peer]
	if code == "" {
		return nil
	}
	return l.rooms[code]
}

func (l *Lobby) uniqueCode() string {
	for {
		var b [4]byte
		_, _ = rand.Read(b[:])
		code := make([]byte, 4)
		for i := 0; i < 4; i++ {
			code[i] = codeAlphabet[int(b[i])%len(codeAlphabet)]
		}
		s := string(code)
		if _, exists := l.rooms[s]; !exists {
			return s
		}
	}
}

func minPeer(members map[int]bool) int {
	best := 0
	for id := range members {
		if best == 0 || id < best {
			best = id
		}
	}
	return best
}
