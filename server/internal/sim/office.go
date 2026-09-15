package sim

import (
	"fmt"
	"math"
)

var DeskRect = Rect{X: 520, Y: 780, W: 800, H: 456}
var DeskDoor = Vec{X: 900, Y: 774}

type Door struct {
	ID      string
	Title   string
	Pos     Vec
	Closed  bool
	Opening bool
	OpenLeft float64
}

func (d *Door) Rect() Rect {
	return RectFromCenter(d.Pos, 100, 18)
}

func (d *Door) Slam() {
	d.Closed = true
	d.Opening = false
	d.OpenLeft = 0
}

func (d *Door) BeginOpen() bool {
	if !d.Closed || d.Opening {
		return false
	}
	d.Opening = true
	d.OpenLeft = DoorOpenTime
	return true
}

func (d *Door) ForceOpen() {
	d.Closed = false
	d.Opening = false
	d.OpenLeft = 0
}

func (d *Door) Tick(dt float64) {
	if !d.Opening {
		return
	}
	d.OpenLeft = math.Max(0, d.OpenLeft-dt)
	if d.OpenLeft <= 0 {
		d.ForceOpen()
	}
}

type Office struct {
	Walls     []Rect
	Blockers  []Rect
	Doors     []*Door
	Points    map[string]Vec
	Occupiers map[string]int
}

func DefaultOffice() *Office {
	o := &Office{
		Points:    map[string]Vec{},
		Occupiers: map[string]int{},
	}
	walls := []Rect{
		{16, 16, 2528, 24}, {16, 1480, 2528, 24}, {16, 16, 24, 1488}, {2520, 16, 24, 1488},
		{40, 544, 88, 20}, {232, 544, 260, 20}, {492, 544, 196, 20}, {792, 544, 180, 20},
		{972, 544, 316, 20}, {1392, 544, 300, 20}, {1692, 544, 96, 20}, {1892, 544, 628, 20},
		{488, 40, 20, 524}, {968, 40, 20, 524}, {1688, 40, 20, 524},
		{40, 764, 88, 20}, {232, 764, 276, 20}, {508, 764, 332, 20}, {960, 764, 360, 20},
		{1320, 764, 392, 20}, {1712, 764, 112, 20}, {1952, 764, 568, 20},
		{504, 780, 20, 140}, {504, 1060, 20, 420}, {1320, 780, 20, 700},
		{524, 1236, 796, 20}, {524, 1256, 796, 224},
	}
	o.Walls = walls
	o.Blockers = []Rect{
		RectFromCenter(Vec{730, 974}, 236, 36),
		RectFromCenter(Vec{1070, 974}, 236, 36),
		RectFromCenter(Vec{1240, 974}, 108, 36),
		RectFromCenter(Vec{2120, 1096}, 210, 42),
	}
	o.Points["coffee_0"] = Vec{1180, 198}
	o.Points["coffee_1"] = Vec{1460, 198}
	o.Points["toilet_0"] = Vec{160, 200}
	o.Points["toilet_1"] = Vec{360, 200}
	o.Points["punch_0"] = Vec{160, 1000}
	o.Points["punch_1"] = Vec{380, 1000}
	o.Points["meeting"] = Vec{2120, 1172}
	o.Points["lounge"] = Vec{2000, 220}
	o.Points["corridor"] = Vec{1280, CorridorY}
	o.Points["boss_spawn"] = Vec{1280, CorridorY}
	seats := []Vec{{670, 1048}, {790, 1048}, {1010, 1048}, {1130, 1048}, {1240, 1048}}
	for i, seat := range seats {
		n := i + 1
		o.Points[fmt.Sprintf("desk_%d", n)] = Vec{seat.X, 970}
		o.Points[fmt.Sprintf("seat_%d", n)] = seat
		o.Points[fmt.Sprintf("sup_%d", n)] = seat.Add(Vec{0, 58})
	}
	o.Doors = []*Door{
		{ID: "toilet", Title: "厕所", Pos: Vec{180, 554}},
		{ID: "storage", Title: "储物", Pos: Vec{740, 554}},
		{ID: "tea", Title: "茶水", Pos: Vec{1340, 554}},
		{ID: "lounge", Title: "休息", Pos: Vec{1840, 554}},
		{ID: "lobby", Title: "门厅", Pos: Vec{180, 774}},
		{ID: "desk", Title: "工位", Pos: DeskDoor},
		{ID: "meeting", Title: "会议", Pos: Vec{1860, 774}},
	}
	for id := range o.Points {
		o.Occupiers[id] = -1
	}
	return o
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [8]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}

func (o *Office) ResetShift() {
	for _, d := range o.Doors {
		d.ForceOpen()
	}
	for k := range o.Occupiers {
		o.Occupiers[k] = -1
	}
}

func (o *Office) Solids() []Rect {
	out := append([]Rect{}, o.Walls...)
	out = append(out, o.Blockers...)
	for _, d := range o.Doors {
		if d.Closed {
			out = append(out, d.Rect())
		}
	}
	return out
}

func (o *Office) CircleHits(c Vec, radius float64) bool {
	for _, r := range o.Solids() {
		if CircleHitsRect(c, radius, r) {
			return true
		}
	}
	return false
}

func (o *Office) Resolve(c Vec, radius float64) Vec {
	p := c
	for i := 0; i < 4; i++ {
		moved := false
		for _, r := range o.Solids() {
			n := PushCircleOut(p, radius, r)
			if n != p {
				p = n
				moved = true
			}
		}
		if !moved {
			break
		}
	}
	return p
}

func (o *Office) MoveSlide(from Vec, delta Vec, radius float64) Vec {
	nx := Vec{from.X + delta.X, from.Y}
	if !o.CircleHits(nx, radius) {
		from.X = nx.X
	}
	ny := Vec{from.X, from.Y + delta.Y}
	if !o.CircleHits(ny, radius) {
		from.Y = ny.Y
	}
	return from
}

func (o *Office) CanSee(from, to Vec) bool {
	for _, r := range o.Solids() {
		if SegmentHitsRect(from, to, r) {
			return false
		}
	}
	return true
}

func (o *Office) RoomID(p Vec) int {
	if p.Y < TopY {
		if p.X < XToilet {
			return 1
		}
		if p.X < XNorth {
			return 2
		}
		if p.X < XTea {
			return 3
		}
		return 4
	}
	if p.Y < BotY {
		return 5
	}
	if p.X < XToilet {
		return 6
	}
	if p.X < XDesk {
		return 7
	}
	return 8
}

func (o *Office) SameView(a, b Vec) bool {
	if o.RoomID(a) != o.RoomID(b) {
		return false
	}
	if o.RoomID(a) == 5 {
		return (a.X < 1280) == (b.X < 1280)
	}
	return true
}

func (o *Office) DoorPosForRoom(room int, from Vec) Vec {
	switch room {
	case 1:
		return Vec{180, 554}
	case 2:
		return Vec{740, 554}
	case 3:
		return Vec{1340, 554}
	case 4:
		return Vec{1840, 554}
	case 6:
		return Vec{180, 774}
	case 7:
		return DeskDoor
	case 8:
		return Vec{1860, 774}
	default:
		return from
	}
}

func (o *Office) PathTo(from, to Vec) Vec {
	ra, rb := o.RoomID(from), o.RoomID(to)
	if ra == rb {
		return o.avoidFurniture(from, to)
	}
	if ra != 5 {
		dpos := o.DoorPosForRoom(ra, from)
		if from.Dist(dpos) > 22 {
			return o.avoidFurniture(from, dpos)
		}
		return Vec{dpos.X, CorridorY}
	}
	if rb != 5 {
		dpos := o.DoorPosForRoom(rb, to)
		if math.Abs(from.X-dpos.X) > 18 {
			return Vec{dpos.X, CorridorY}
		}
		if from.Dist(dpos) > 18 {
			return dpos
		}
		return to
	}
	return to
}

func (o *Office) avoidFurniture(from, to Vec) Vec {
	if o.RoomID(from) != 7 {
		return to
	}
	aisle := DeskDoor.X
	north := from.Y < 1000
	wantN := to.Y < 1000
	if north == wantN {
		return to
	}
	if math.Abs(from.X-aisle) > 22 {
		return Vec{aisle, from.Y}
	}
	if north {
		return Vec{aisle, 1056}
	}
	return Vec{aisle, 880}
}

func (o *Office) NearestDoor(from Vec, maxD float64) *Door {
	var best *Door
	bestD := maxD
	for _, d := range o.Doors {
		dist := from.Dist(d.Pos)
		if dist < bestD {
			bestD = dist
			best = d
		}
	}
	return best
}

func (o *Office) TryDoor(kind int, pos Vec) bool {
	d := o.NearestDoor(pos, DoorRange)
	if d == nil {
		return false
	}
	if d.Opening {
		return true
	}
	if d.Closed {
		d.BeginOpen()
		return true
	}
	if kind == KindEmployee {
		d.Slam()
		return true
	}
	return false
}

func (o *Office) NearestPunch(from Vec) Vec {
	a, b := o.Points["punch_0"], o.Points["punch_1"]
	if from.Dist(a) <= from.Dist(b) {
		return a
	}
	return b
}

func (o *Office) SeatForSlot(slot int) Vec {
	return o.Points[fmt.Sprintf("seat_%d", EmployeeIndex(slot)+1)]
}

func (o *Office) NearestSpot(prefix string, from Vec, maxD float64) string {
	best := ""
	bestD := maxD
	key := prefix + "_"
	for id := range o.Occupiers {
		if len(id) < len(key) || id[:len(key)] != key {
			continue
		}
		p, ok := o.Points[id]
		if !ok {
			continue
		}
		d := from.Dist(p)
		if d < bestD {
			bestD = d
			best = id
		}
	}
	return best
}

func (o *Office) NearestFree(prefix string, from Vec) string {
	best := ""
	bestD := 1e9
	key := prefix + "_"
	for id, who := range o.Occupiers {
		if len(id) < len(key) || id[:len(key)] != key {
			continue
		}
		if who != -1 {
			continue
		}
		p, ok := o.Points[id]
		if !ok {
			continue
		}
		d := from.Dist(p)
		if d < bestD {
			bestD = d
			best = id
		}
	}
	return best
}

func (o *Office) TakeSpot(id string, actorID int) bool {
	if id == "" {
		return false
	}
	who := o.Occupiers[id]
	if who != -1 && who != actorID {
		return false
	}
	o.Occupiers[id] = actorID
	return true
}

func (o *Office) FreeSpot(id string, actorID int) {
	if id != "" && o.Occupiers[id] == actorID {
		o.Occupiers[id] = -1
	}
}
