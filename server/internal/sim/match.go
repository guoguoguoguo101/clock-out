package sim

import "clockout/server/internal/protocol"

type Bot interface {
	Tick(dt float64)
}

type Match struct {
	Phase     string
	Playing   bool
	Short     bool
	Elapsed   float64
	TimeLeft  float64
	Countdown float64
	Slots     map[int]int // slot -> peer; -1 empty, 0 bot
	Names     map[int]string
	ClockLog  map[int]float64
	Result    map[string]any
	Actors    map[int]*Actor
	Office    *Office
	Bots      []Bot
	Events    []protocol.Event
}

func NewMatch() *Match {
	m := &Match{
		Phase:    "lobby",
		TimeLeft: MatchSeconds,
		Slots: map[int]int{
			SlotBoss: -1, SlotEmpA: -1, SlotEmpB: -1, SlotEmpC: -1, SlotEmpD: -1, SlotEmpE: -1,
		},
		Names:    map[int]string{},
		ClockLog: map[int]float64{},
		Actors:   map[int]*Actor{},
		Office:   DefaultOffice(),
	}
	return m
}

func (m *Match) Claim(peer, slot int, name string) bool {
	if m.Phase != "lobby" {
		return false
	}
	if _, ok := m.Slots[slot]; !ok {
		return false
	}
	for s, p := range m.Slots {
		if p == peer {
			m.Slots[s] = -1
		}
	}
	if cur := m.Slots[slot]; cur != -1 && cur != peer && cur != 0 {
		return false
	}
	m.Slots[slot] = peer
	m.Names[peer] = name
	return true
}

func (m *Match) SetBot(slot int, on bool) bool {
	if m.Phase != "lobby" {
		return false
	}
	if _, ok := m.Slots[slot]; !ok {
		return false
	}
	cur := m.Slots[slot]
	if on {
		if cur > 0 {
			return false
		}
		m.Slots[slot] = 0
		m.Names[0] = "Bot"
	} else {
		if cur != 0 {
			return false
		}
		m.Slots[slot] = -1
	}
	return true
}

func (m *Match) FillEmptyBots() {
	if m.Phase != "lobby" {
		return
	}
	for s, p := range m.Slots {
		if p == -1 {
			m.Slots[s] = 0
		}
	}
	m.Names[0] = "Bot"
}

func (m *Match) Start(short bool, instant bool) bool {
	if m.Phase != "lobby" {
		return false
	}
	m.Short = short
	if short {
		m.TimeLeft = ShortMatchSeconds
	} else {
		m.TimeLeft = MatchSeconds
	}
	m.Elapsed = 0
	m.ClockLog = map[int]float64{}
	m.Bots = nil
	m.spawnAll()
	if instant {
		m.Phase = "playing"
		m.Playing = true
		m.Countdown = 0
	} else {
		m.Phase = "countdown"
		m.Playing = false
		m.Countdown = Countdown
	}
	return true
}

func (m *Match) spawnAll() {
	m.Actors = map[int]*Actor{}
	m.Office.ResetShift()
	m.Bots = nil
	for s, pid := range m.Slots {
		if pid < 0 {
			continue
		}
		name := m.nameFor(pid, s)
		a := NewActor(s, pid, name, m.Office)
		m.Actors[s] = a
		if pid == 0 {
			if s == SlotBoss {
				m.Bots = append(m.Bots, &BossBot{Actor: a, Map: m.Office, Match: m})
			} else {
				m.Bots = append(m.Bots, &EmployeeBot{Actor: a, Map: m.Office, Match: m})
			}
		}
	}
}

func (m *Match) Tick(dt float64) {
	if m.Phase == "countdown" {
		m.Countdown -= dt
		if m.Countdown <= 0 {
			m.Phase = "playing"
			m.Playing = true
		}
		return
	}
	if m.Phase != "playing" {
		return
	}
	m.Elapsed += dt
	m.TimeLeft = maxf(0, m.TimeLeft-dt)
	for _, b := range m.Bots {
		b.Tick(dt)
	}
	for _, a := range m.Actors {
		a.Tick(m, dt)
	}
	for _, d := range m.Office.Doors {
		d.Tick(dt)
	}
	if m.TimeLeft <= 0 || m.allPunched() {
		m.Finish()
	}
}

func (m *Match) ApplyInput(peer int, in Input) {
	if !m.Playing {
		return
	}
	for _, a := range m.Actors {
		if a.Peer == peer && peer > 0 {
			a.ApplyInput(in)
			return
		}
	}
}

func (m *Match) IsSupervised(emp *Actor) bool {
	boss := m.Actors[SlotBoss]
	if boss == nil {
		return false
	}
	if boss.Pos.Dist(emp.Pos) <= SuperviseDist {
		return true
	}
	sid := emp.OccupyID
	if sid == "" || len(sid) < 5 || sid[:5] != "seat_" {
		if emp.LastSeat > 0 {
			sid = "seat_" + itoa(emp.LastSeat)
		} else {
			return false
		}
	}
	key := "sup_" + sid[5:]
	p, ok := m.Office.Points[key]
	if !ok {
		return false
	}
	return boss.Pos.Dist(p) <= SuperviseDist
}

func (m *Match) IsWatched(emp *Actor) bool {
	boss := m.Actors[SlotBoss]
	if boss == nil {
		return false
	}
	return m.Office.SameView(boss.Pos, emp.Pos)
}

func (m *Match) IsCatchable(emp *Actor) bool {
	if emp.Kind != KindEmployee {
		return false
	}
	if emp.State == StateSlack || emp.State == StateCoffee || emp.State == StateToilet {
		return true
	}
	return emp.RescueLeft > 0 || emp.Carrying >= 0
}

func (m *Match) TryCatch(boss *Actor) bool {
	for _, e := range m.Actors {
		if !m.IsCatchable(e) {
			continue
		}
		if boss.Pos.Dist(e.Pos) > CatchRange {
			continue
		}
		m.CatchEmployee(e)
		return true
	}
	return false
}

func (m *Match) CatchEmployee(emp *Actor) { m.StartTalk(emp) }

func (m *Match) StartTalk(emp *Actor) {
	if emp.State == StateClocking || emp.State == StateLeft || emp.State == StateTalk || emp.State == StateMeeting {
		return
	}
	emp.BeginTalk(m)
	m.emit(protocol.Event{Kind: "talk", Slot: emp.Slot})
}

func (m *Match) FinishTalk(emp *Actor) {
	if emp.State != StateTalk {
		return
	}
	repeat := emp.CatchChain > 0
	add := CatchHoursFirst
	if repeat {
		add = CatchHoursRepeat
	}
	emp.ApplyCatch(m, repeat)
	m.emit(protocol.Event{Kind: "catch", Slot: emp.Slot, Repeat: repeat, AddHours: add})
}

func (m *Match) NearestCarryTarget(carrier *Actor) *Actor {
	if carrier.Skin != SkinPelican || carrier.CarryRecov > 0 || carrier.Carrying >= 0 {
		return nil
	}
	var best *Actor
	dist := CarryRange
	for _, c := range m.Actors {
		if c == carrier || c.Kind != KindEmployee || c.CarriedBy >= 0 {
			continue
		}
		switch c.State {
		case StateMeeting, StateClocking, StateLeft:
			continue
		}
		d := carrier.Pos.Dist(c.Pos)
		if d < dist && m.Office.CanSee(carrier.Pos, c.Pos) {
			best = c
			dist = d
		}
	}
	return best
}

func (m *Match) TryBike(rider *Actor) bool {
	if !m.Playing || rider.IsBot() {
		return false
	}
	if rider.Skin != SkinKangaroo {
		return false
	}
	if rider.State != StateWalk || rider.StandLock > 0 {
		return false
	}
	if rider.BikeLeft > 0 || rider.Carrying >= 0 || rider.CarriedBy >= 0 {
		return false
	}
	rider.BikeLeft = BikeDuration
	m.emit(protocol.Event{Kind: "bike", Slot: rider.Slot, On: true})
	return true
}

func (m *Match) ClearBike(rider *Actor) {
	rider.BikeLeft = 0
	m.emit(protocol.Event{Kind: "bike", Slot: rider.Slot, On: false})
}

func (m *Match) TryCarry(carrier *Actor) bool {
	if !m.Playing || carrier.IsBot() {
		return false
	}
	if carrier.State != StateWalk || carrier.StandLock > 0 || carrier.CarriedBy >= 0 {
		return false
	}
	pass := m.NearestCarryTarget(carrier)
	if pass == nil {
		return false
	}
	if pass.State == StateTalk {
		pass.CarrySaved = pass.TalkProg
	} else {
		pass.CarrySaved = -1
	}
	pass.standUp(m)
	pass.ClearRescue()
	if pass.BikeLeft > 0 {
		m.ClearBike(pass)
	}
	carrier.ClearRescue()
	if pass.Pos.X >= carrier.Pos.X {
		carrier.Facing.X = 1
	} else {
		carrier.Facing.X = -1
	}
	carrier.Carrying = pass.Slot
	carrier.CarryLeft = CarryDuration
	carrier.CarryWindup = CarryWindup
	pass.CarriedBy = carrier.Slot
	pass.State = StateCarried
	pass.Vel = Vec{}
	m.emit(protocol.Event{Kind: "carry", Slot: carrier.Slot, Passenger: pass.Slot, On: true, X: pass.Pos.X, Y: pass.Pos.Y, Facing: carrier.Facing.X})
	return true
}

func (m *Match) ReleaseActorCarry(actor *Actor, interrupted bool) {
	if actor.Carrying >= 0 {
		m.ReleaseCarry(actor, interrupted)
	} else if actor.CarriedBy >= 0 {
		if c := m.Actors[actor.CarriedBy]; c != nil {
			m.ReleaseCarry(c, interrupted)
		}
	}
}

func (m *Match) ReleaseCarry(carrier *Actor, interrupted bool) {
	if carrier.Carrying < 0 {
		return
	}
	pass := m.Actors[carrier.Carrying]
	if pass == nil {
		carrier.Carrying = -1
		return
	}
	landing := carrier.Pos
	dirs := []Vec{{carrier.Facing.X, 0}, {0, 1}, {0, -1}, {-1, 0}, {1, 0}}
	for _, dir := range dirs {
		if dir.Len() < 0.01 {
			continue
		}
		cand := carrier.Pos.Add(dir.Normalized().Mul(30))
		if !m.Office.CircleHits(cand, ActorRadius) {
			landing = cand
			break
		}
	}
	carrier.Carrying = -1
	carrier.CarryLeft = 0
	carrier.CarryWindup = 0
	carrier.CarryRecov = CarryRecovery
	pass.CarriedBy = -1
	if interrupted && pass.CarrySaved >= 0 {
		pass.State = StateTalk
		pass.TalkProg = maxf(0, pass.CarrySaved)
	} else {
		pass.State = StateWalk
		pass.TalkProg = 0
	}
	pass.CarrySaved = -1
	pass.Pos = landing
	pass.In = Vec{}
	pass.WantInteract = false
	m.emit(protocol.Event{Kind: "carry", Slot: carrier.Slot, Passenger: pass.Slot, On: false, X: landing.X, Y: landing.Y, Interrupted: interrupted, Facing: carrier.Facing.X})
}

func (m *Match) NearestTalk(from Vec, maxD float64) *Actor {
	var best *Actor
	bestD := maxD
	for _, e := range m.Actors {
		if e.Kind != KindEmployee || e.State != StateTalk {
			continue
		}
		d := from.Dist(e.Pos)
		if d < bestD {
			bestD = d
			best = e
		}
	}
	return best
}

func (m *Match) TryRescue(rescuer *Actor) bool {
	if rescuer.StandLock > 0 || rescuer.RescueLeft > 0 || rescuer.State != StateWalk {
		return false
	}
	vic := m.NearestTalk(rescuer.Pos, RescueRange)
	if vic == nil {
		return false
	}
	if m.IsWatched(vic) {
		boss := m.Actors[SlotBoss]
		if boss != nil && boss.Pos.Dist(rescuer.Pos) <= CatchRange {
			m.StartTalk(rescuer)
		}
		return true
	}
	rescuer.RescueSlot = vic.Slot
	rescuer.RescueLeft = RescueTime
	return true
}

func (m *Match) TickRescue(rescuer *Actor, dt float64) bool {
	vic := m.Actors[rescuer.RescueSlot]
	if vic == nil || vic.State != StateTalk {
		rescuer.ClearRescue()
		return false
	}
	if m.IsWatched(vic) {
		rescuer.ClearRescue()
		return false
	}
	if rescuer.Pos.Dist(vic.Pos) > RescueRange+16 {
		rescuer.ClearRescue()
		return false
	}
	rescuer.RescueLeft -= dt
	if rescuer.RescueLeft <= 0 {
		m.CompleteRescue(rescuer, vic)
		return false
	}
	return true
}

func (m *Match) CompleteRescue(rescuer, vic *Actor) {
	vic.EndTalkRescued()
	rescuer.ClearRescue()
	vic.BoostLeft = RescueBoostTime
	rescuer.BoostLeft = RescueBoostTime
	m.emit(protocol.Event{Kind: "rescue", Slot: vic.Slot, BySlot: rescuer.Slot})
}

func (m *Match) TryMeeting(boss *Actor) bool {
	var best *Actor
	bestD := MeetingRange
	for _, e := range m.Actors {
		if e.Kind != KindEmployee {
			continue
		}
		if e.State == StateLeft || e.State == StateClocking || e.State == StateCarried {
			continue
		}
		d := boss.Pos.Dist(e.Pos)
		if d > bestD {
			continue
		}
		if !m.Office.CanSee(boss.Pos, e.Pos) {
			continue
		}
		best = e
		bestD = d
	}
	if best == nil {
		return false
	}
	best.SendToMeeting(m, MeetingTime, m.Office.Points["meeting"])
	return true
}

func (m *Match) CastKPI() {
	for _, e := range m.Actors {
		if e.Kind == KindEmployee && e.State != StateLeft {
			e.Hours += KPIHours
		}
	}
	m.emit(protocol.Event{Kind: "kpi"})
}

func (m *Match) OnClockOut(slot int) {
	m.ClockLog[slot] = m.Elapsed
	if m.allPunched() {
		m.Finish()
	}
}

func (m *Match) allPunched() bool {
	any := false
	for _, s := range EmployeeSlots {
		a := m.Actors[s]
		if a == nil {
			continue
		}
		any = true
		if a.State != StateLeft {
			return false
		}
	}
	return any
}

func (m *Match) Finish() {
	if m.Phase == "result" {
		return
	}
	for _, a := range m.Actors {
		m.ReleaseActorCarry(a, false)
	}
	m.Playing = false
	m.Phase = "result"
	punched := 0
	var people []any
	for _, s := range EmployeeSlots {
		a := m.Actors[s]
		if a == nil {
			continue
		}
		win := a.State == StateLeft
		if win {
			punched++
		}
		t := -1.0
		if v, ok := m.ClockLog[s]; ok {
			t = v
		}
		people = append(people, map[string]any{"slot": s, "name": a.Name, "win": win, "time": t})
	}
	boss := "胜"
	if punched == 3 || punched == 4 {
		boss = "平"
	} else if punched >= 5 {
		boss = "负"
	}
	m.Result = map[string]any{"punched": punched, "boss": boss, "people": people}
	m.emit(protocol.Event{Kind: "result", Result: m.Result})
}

func (m *Match) ResetLobby() {
	m.Office.ResetShift()
	for s, p := range m.Slots {
		if p == 0 {
			m.Slots[s] = -1
		}
	}
	m.Playing = false
	m.Phase = "lobby"
	m.Countdown = 0
	m.ClockLog = map[int]float64{}
	m.Result = nil
	m.Actors = map[int]*Actor{}
	m.Bots = nil
}

func (m *Match) ConvertToBot(slot int) {
	a := m.Actors[slot]
	if a == nil {
		return
	}
	m.ReleaseActorCarry(a, true)
	a.Peer = 0
	m.Slots[slot] = 0
	m.Names[0] = "Bot"
	a.Name = m.nameFor(0, slot)
	if slot == SlotBoss {
		m.Bots = append(m.Bots, &BossBot{Actor: a, Map: m.Office, Match: m})
	} else {
		m.Bots = append(m.Bots, &EmployeeBot{Actor: a, Map: m.Office, Match: m})
	}
}

func (m *Match) HumanCount() int {
	n := 0
	seen := map[int]bool{}
	for _, p := range m.Slots {
		if p > 0 && !seen[p] {
			seen[p] = true
			n++
		}
	}
	return n
}

func (m *Match) Snapshot() protocol.Snapshot {
	snap := protocol.Snapshot{
		Phase: m.Phase, Elapsed: m.Elapsed, Left: m.TimeLeft, Countdown: m.Countdown,
		Occupiers: map[string]int{},
	}
	for k, v := range m.Office.Occupiers {
		snap.Occupiers[k] = v
	}
	for _, d := range m.Office.Doors {
		snap.Doors = append(snap.Doors, protocol.DoorSnap{ID: d.ID, Closed: d.Closed, Opening: d.Opening, Left: d.OpenLeft})
	}
	for s := 0; s <= SlotEmpE; s++ {
		a := m.Actors[s]
		if a == nil {
			continue
		}
		snap.Actors = append(snap.Actors, protocol.ActorSnap{
			Slot: a.Slot, Peer: a.Peer, Name: a.Name, X: a.Pos.X, Y: a.Pos.Y,
			State: a.State, Hours: a.Hours, Energy: a.Energy, Visible: a.Visible,
			MeetingCD: a.MeetingCD, KPICD: a.KPICD, DashCD: a.DashCD, Occupy: a.OccupyID,
			Talk: a.TalkProg, Rescue: a.RescueLeft, Bike: a.BikeLeft,
			Carrying: a.Carrying, CarriedBy: a.CarriedBy, FacingX: a.Facing.X, StandLock: a.StandLock,
		})
	}
	return snap
}

func (m *Match) DrainEvents() []protocol.Event {
	ev := m.Events
	m.Events = nil
	return ev
}

func (m *Match) emit(e protocol.Event) {
	m.Events = append(m.Events, e)
}

func (m *Match) nameFor(pid, slot int) string {
	if pid == 0 {
		return "Bot·" + SlotNames[slot]
	}
	if n, ok := m.Names[pid]; ok {
		return n
	}
	return SlotNames[slot]
}

func (m *Match) LobbyState(code string, captain int) protocol.Lobby {
	slots := map[string]int{}
	for s, p := range m.Slots {
		slots[itoa(s)] = p
	}
	names := map[string]string{}
	for id, n := range m.Names {
		names[itoa(id)] = n
	}
	return protocol.Lobby{Code: code, Phase: m.Phase, Short: m.Short, Captain: captain, Slots: slots, Names: names}
}
