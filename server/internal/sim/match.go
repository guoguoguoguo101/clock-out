package sim

import (
	"clockout/server/internal/protocol"
	"math/rand"
)

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
	IncidentActive    bool
	IncidentLeft      float64
	IncidentBlameSlot int
	IncidentTerminal  Vec
	IncidentFixed     bool

	// 随机事件
	EventActive    string
	EventLeft      float64
	EventTimer     float64
	EventCount     int
	EventUsed      []string
	AnonRevealSlot int
	AnonRevealLeft float64
	BlackoutActive bool
	DeliverySpots  map[int]Vec
	IntranetDown   bool
	IntranetBoostLeft float64
}

func NewMatch() *Match {
	m := &Match{
		Phase:    "lobby",
		TimeLeft: MatchSeconds,
		IncidentBlameSlot: -1,
		AnonRevealSlot: -1,
		DeliverySpots: map[int]Vec{},
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
	if m.IncidentActive {
		m.tickIncident(dt)
	}
	m.tickRandomEvents(dt)
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
	dist := SuperviseDist
	if m.IncidentActive {
		dist *= IncidentBossRangeMul
	}
	if boss.Pos.Dist(emp.Pos) <= dist {
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
	return m.IsLungeTarget(emp)
}

func (m *Match) IsLungeTarget(emp *Actor) bool {
	if emp == nil || emp.Kind != KindEmployee {
		return false
	}
	switch emp.State {
	case StateLeft, StateTalk, StateMeeting, StateClocking, StateCarried:
		return false
	}
	return true
}

func (m *Match) IsHoldTarget(emp *Actor) bool {
	return emp != nil && emp.Kind == KindEmployee && (emp.State == StateTalk || emp.State == StateMeeting)
}

func (m *Match) TryCatch(boss *Actor) bool {
	return m.StartLunge(boss)
}

func (m *Match) StartLunge(boss *Actor) bool {
	if boss.LungeLeft > 0 || boss.LungeStun > 0 || boss.DashLeft > 0 {
		return false
	}
	if boss.Facing.Len() < 0.12 {
		boss.Facing = Vec{0, 1}
	}
	boss.LungeLeft = TigerLungeTime
	boss.LungeHit = false
	return true
}

func (m *Match) LungeVictim(boss *Actor, from, to Vec) *Actor {
	var best *Actor
	bestD := TigerLungeRadius
	for _, e := range m.Actors {
		if e == boss || !m.IsLungeTarget(e) {
			continue
		}
		d := DistPointSeg(e.Pos, from, to)
		if d <= bestD {
			bestD = d
			best = e
		}
	}
	return best
}

func (m *Match) GrabLunge(boss, emp *Actor) {
	boss.LungeLeft = 0
	boss.LungeHit = true
	boss.LungeStun = TigerLungeHit
	if boss.PowerPips < TigerPowerMax {
		boss.PowerPips++
	}
	m.StartTalk(emp)
}

func (m *Match) MissLunge(boss *Actor) {
	if boss.LungeHit {
		boss.LungeLeft = 0
		return
	}
	boss.LungeLeft = 0
	boss.LungeStun = TigerLungeMiss
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
	emp.ApplyCatch(m, repeat)
	m.emit(protocol.Event{Kind: "catch", Slot: emp.Slot, Repeat: repeat})
}

func (m *Match) FinishMeeting(emp *Actor) {
	if emp.State != StateMeeting {
		return
	}
	emp.ApplyMeetingFail(m)
	m.emit(protocol.Event{Kind: "catch", Slot: emp.Slot, Repeat: true})
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
		if !m.IsHoldTarget(e) {
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
	rescuer.RescueSlot = vic.Slot
	rescuer.RescueLeft = RescueTime
	return true
}

func (m *Match) TickRescue(rescuer *Actor, dt float64) bool {
	vic := m.Actors[rescuer.RescueSlot]
	if vic == nil || !m.IsHoldTarget(vic) {
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
	vic.EndHoldRescued()
	rescuer.ClearRescue()
	m.emit(protocol.Event{Kind: "rescue", Slot: vic.Slot, BySlot: rescuer.Slot})
}

func (m *Match) TryMeeting(boss *Actor) bool {
	if boss.PowerPips < TigerPowerMax || boss.LungeLeft > 0 || boss.LungeStun > 0 {
		return false
	}
	aim := boss.Facing
	if aim.Len() < 0.12 {
		aim = Vec{0, 1}
	}
	aim = aim.Normalized()
	var best *Actor
	bestD := MeetingRange
	for _, e := range m.Actors {
		if e.Kind != KindEmployee {
			continue
		}
		if e.State == StateLeft || e.State == StateClocking || e.State == StateMeeting || e.State == StateCarried {
			continue
		}
		delta := e.Pos.Sub(boss.Pos)
		d := delta.Len()
		if d > bestD || d < 8 {
			continue
		}
		if aim.Dot(delta.Normalized()) < 0.5736 {
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
	boss.PowerPips = 0
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

// ── 线上事故 ──────────────────────────────

var incidentSpots = []Vec{
	{1280, 670}, {280, 670}, {2100, 670}, {730, 1000}, {1100, 1000},
}

func (m *Match) CastIncident(boss *Actor) bool {
	if m.IncidentActive {
		return false
	}
	var best *Actor
	bestDone := -1.0
	for _, e := range m.Actors {
		if e.Kind != KindEmployee || e.State == StateLeft || e.State == StateClocking {
			continue
		}
		if e.Hours > bestDone {
			bestDone = e.Hours
			best = e
		}
	}
	if best == nil {
		return false
	}
	idx := int(m.Elapsed*1000) % len(incidentSpots)
	m.IncidentTerminal = incidentSpots[idx]
	m.IncidentActive = true
	m.IncidentLeft = IncidentDuration
	m.IncidentBlameSlot = best.Slot
	m.IncidentFixed = false
	for _, e := range m.Actors {
		e.IsBlameTarget = e.Slot == best.Slot
		e.Fixing = false
		e.FixProgress = 0
		e.BlamedOnce = false
	}
	m.emit(protocol.Event{Kind: "incident_start", Slot: best.Slot, X: m.IncidentTerminal.X, Y: m.IncidentTerminal.Y})
	return true
}

func (m *Match) tickIncident(dt float64) {
	m.IncidentLeft -= dt
	for _, e := range m.Actors {
		if !e.Fixing || e.Kind != KindEmployee {
			continue
		}
		if e.State == StateLeft || e.State == StateTalk || e.State == StateMeeting {
			e.Fixing = false
			e.FixProgress = 0
			continue
		}
		if e.Pos.Dist(m.IncidentTerminal) > InteractRange+40 {
			e.Fixing = false
			e.FixProgress = 0
			continue
		}
		if e.In.Len() > 0.12 {
			e.Fixing = false
			e.FixProgress = 0
			continue
		}
		dur := IncidentFixTime
		if !e.IsBlameTarget {
			dur *= 0.6
		}
		e.FixProgress = minf(1, e.FixProgress+dt/dur)
		e.Vel = Vec{}
		if e.FixProgress >= 1 {
			m.completeFix(e)
			return
		}
	}
	if m.IncidentLeft <= 0 {
		m.endIncident(false)
	}
}

func (m *Match) completeFix(fixer *Actor) {
	isAssist := !fixer.IsBlameTarget
	fixer.Fixing = false
	fixer.FixProgress = 0
	m.emit(protocol.Event{Kind: "fix_done", Slot: fixer.Slot, On: isAssist})
	if isAssist {
		m.IncidentLeft = maxf(0, m.IncidentLeft-5.0)
		if m.IncidentLeft <= 0 {
			m.endIncident(true)
		}
	} else {
		m.endIncident(true)
	}
}

func (m *Match) endIncident(fixed bool) {
	m.IncidentActive = false
	m.IncidentFixed = fixed
	if !fixed {
		blame := m.Actors[m.IncidentBlameSlot]
		if blame != nil && blame.State != StateLeft {
			blame.Hours += IncidentFailHours
			blame.StandLock = maxf(blame.StandLock, 2.0)
		}
	}
	for _, e := range m.Actors {
		e.IsBlameTarget = false
		e.Fixing = false
		e.FixProgress = 0
	}
	m.emit(protocol.Event{Kind: "incident_end", Slot: m.IncidentBlameSlot, On: fixed})
	m.IncidentBlameSlot = -1
	m.IncidentLeft = 0
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
		IncidentActive: m.IncidentActive,
		IncidentLeft:   m.IncidentLeft,
		IncidentBlame:  m.IncidentBlameSlot,
		IncidentX:      m.IncidentTerminal.X,
		IncidentY:      m.IncidentTerminal.Y,
		EventActive:    m.EventActive,
		EventLeft:      m.EventLeft,
		AnonRevealSlot: m.AnonRevealSlot,
		AnonRevealLeft: m.AnonRevealLeft,
		BlackoutActive: m.BlackoutActive,
		IntranetDown:   m.IntranetDown,
		IntranetBoostLeft: m.IntranetBoostLeft,
	}
	if len(m.DeliverySpots) > 0 {
		snap.DeliverySpots = map[string][]float64{}
		for k, v := range m.DeliverySpots {
			snap.DeliverySpots[itoa(k)] = []float64{v.X, v.Y}
		}
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

// ── 随机事件系统 ──

var eventPool = []string{"anon_report", "blackout", "delivery", "intranet_down"}
var eventWeights = map[string]int{"anon_report": 16, "blackout": 10, "delivery": 14, "intranet_down": 12}

var deliverySpawnSpots = []Vec{
	{200, 400}, {400, 400}, {600, 400}, {1000, 400},
}

func (m *Match) tickRandomEvents(dt float64) {
	maxEvents := 4
	if m.Short {
		maxEvents = 2
	}
	if m.AnonRevealLeft > 0 {
		m.AnonRevealLeft -= dt
		if m.AnonRevealLeft <= 0 {
			m.AnonRevealSlot = -1
		}
	}
	if m.IntranetBoostLeft > 0 {
		m.IntranetBoostLeft -= dt
	}
	if m.EventCount >= maxEvents {
		return
	}
	if m.EventActive != "" {
		m.tickActiveEvent(dt)
		return
	}
	if m.Elapsed < EventFirstDelay || m.IncidentActive {
		return
	}
	m.EventTimer -= dt
	if m.EventTimer <= 0 {
		m.triggerRandomEvent()
	}
}

func (m *Match) pickRandomEvent() string {
	pool := make([]string, 0, len(eventPool))
	for _, e := range eventPool {
		found := false
		for _, u := range m.EventUsed {
			if u == e {
				found = true
				break
			}
		}
		if !found {
			pool = append(pool, e)
		}
	}
	if len(pool) == 0 {
		m.EventUsed = nil
		pool = append(pool, eventPool...)
	}
	total := 0
	for _, e := range pool {
		total += eventWeights[e]
	}
	r := rand.Intn(total)
	acc := 0
	for _, e := range pool {
		acc += eventWeights[e]
		if r < acc {
			return e
		}
	}
	return pool[len(pool)-1]
}

func (m *Match) triggerRandomEvent() {
	ev := m.pickRandomEvent()
	m.EventUsed = append(m.EventUsed, ev)
	m.EventCount++
	switch ev {
	case "anon_report":
		m.startAnonReport()
	case "blackout":
		m.startBlackout()
	case "delivery":
		m.startDelivery()
	case "intranet_down":
		m.startIntranetDown()
	}
	m.EventTimer = EventMinInterval + rand.Float64()*(EventMaxInterval-EventMinInterval)
}

func (m *Match) tickActiveEvent(dt float64) {
	m.EventLeft -= dt
	switch m.EventActive {
	case "blackout":
		if m.EventLeft <= 0 {
			m.endBlackout()
		}
	case "delivery":
		if m.EventLeft <= 0 || len(m.DeliverySpots) == 0 {
			m.endDelivery()
		}
	case "intranet_down":
		if m.EventLeft <= 0 {
			m.endIntranetDown()
		}
	}
}

func (m *Match) startAnonReport() {
	var candidates []int
	for _, s := range EmployeeSlots {
		a := m.Actors[s]
		if a != nil && a.State != StateLeft && a.State != StateWork {
			candidates = append(candidates, s)
		}
	}
	if len(candidates) == 0 {
		for _, s := range EmployeeSlots {
			if m.Actors[s] != nil {
				candidates = append(candidates, s)
			}
		}
	}
	if len(candidates) == 0 {
		m.EventCount--
		m.EventTimer = 10
		return
	}
	target := candidates[rand.Intn(len(candidates))]
	m.AnonRevealSlot = target
	m.AnonRevealLeft = AnonReportReveal
	m.emit(protocol.Event{Kind: "anon_report", Slot: target})
}

func (m *Match) startBlackout() {
	m.EventActive = "blackout"
	m.EventLeft = BlackoutDuration
	m.BlackoutActive = true
	for _, s := range EmployeeSlots {
		a := m.Actors[s]
		if a != nil && (a.State == StateWork || a.State == StateSlack) {
			if a.OccupyID != "" {
				m.Office.FreeSpot(a.OccupyID, a.Slot)
				a.OccupyID = ""
			}
			a.State = StateWalk
		}
	}
	m.emit(protocol.Event{Kind: "blackout"})
}

func (m *Match) endBlackout() {
	m.BlackoutActive = false
	m.EventActive = ""
	m.EventLeft = 0
	m.emit(protocol.Event{Kind: "blackout_end"})
}

func (m *Match) startDelivery() {
	m.EventActive = "delivery"
	m.EventLeft = DeliveryDuration
	m.DeliverySpots = map[int]Vec{}
	perm := rand.Perm(len(deliverySpawnSpots))
	count := DeliveryCount
	if count > len(deliverySpawnSpots) {
		count = len(deliverySpawnSpots)
	}
	for i := 0; i < count; i++ {
		m.DeliverySpots[i] = deliverySpawnSpots[perm[i]]
	}
	m.emit(protocol.Event{Kind: "delivery"})
}

func (m *Match) endDelivery() {
	m.DeliverySpots = map[int]Vec{}
	m.EventActive = ""
	m.EventLeft = 0
	m.emit(protocol.Event{Kind: "delivery_end"})
}

func (m *Match) TryGrabDelivery(slot int) bool {
	if len(m.DeliverySpots) == 0 {
		return false
	}
	a := m.Actors[slot]
	if a == nil {
		return false
	}
	bestKey := -1
	bestDist := 999999.0
	for k, v := range m.DeliverySpots {
		d := a.Pos.Dist(v)
		if d < 80 && d < bestDist {
			bestDist = d
			bestKey = k
		}
	}
	if bestKey < 0 {
		return false
	}
	delete(m.DeliverySpots, bestKey)
	isBoss := slot == SlotBoss
	if !isBoss {
		a.Energy = minf(a.Energy+30, EnergyMax)
	}
	m.emit(protocol.Event{Kind: "delivery_grab", Slot: slot, On: !isBoss})
	return true
}

func (m *Match) startIntranetDown() {
	m.EventActive = "intranet_down"
	m.EventLeft = IntranetDuration
	m.IntranetDown = true
	for _, s := range EmployeeSlots {
		a := m.Actors[s]
		if a != nil && (a.State == StateWork || a.State == StateSlack) {
			if a.OccupyID != "" {
				m.Office.FreeSpot(a.OccupyID, a.Slot)
				a.OccupyID = ""
			}
			a.State = StateWalk
		}
	}
	m.emit(protocol.Event{Kind: "intranet_down"})
}

func (m *Match) endIntranetDown() {
	m.IntranetDown = false
	m.IntranetBoostLeft = IntranetBoostTime
	m.EventActive = ""
	m.EventLeft = 0
	m.emit(protocol.Event{Kind: "intranet_end"})
}
