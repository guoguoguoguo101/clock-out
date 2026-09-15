package sim

import (
	"strconv"
	"strings"
)

type Input struct {
	DX, DY                           float64
	Interact, Slack, Meeting, KPI, Dash bool
}

type Actor struct {
	Slot        int
	Peer        int
	Name        string
	Kind        int
	Skin        int
	Pos         Vec
	Vel         Vec
	Facing      Vec
	Hours       float64
	Energy      float64
	State       int
	Visible     bool
	CoffeeBuff  float64
	StandLock   float64
	MeetingLeft float64
	CatchChain  float64
	SlackSeen   float64
	OccupyID    string
	LastSeat    int
	TalkProg    float64
	RescueLeft  float64
	RescueSlot  int
	BoostLeft   float64
	Carrying    int
	CarriedBy   int
	CarryLeft   float64
	CarryWindup float64
	CarryRecov  float64
	CarrySaved  float64
	BikeLeft    float64
	MeetingCD   float64
	KPICD       float64
	DashCD      float64
	DashLeft    float64
	KPIFlash    float64
	In          Vec
	WantInteract, WantSlack, WantMeeting, WantKPI, WantDash bool
}

func NewActor(slot, peer int, name string, office *Office) *Actor {
	a := &Actor{
		Slot: slot, Peer: peer, Name: name,
		Kind: KindEmployee, Skin: SkinForSlot[slot],
		Hours: HoursStart, Energy: EnergyStart, State: StateWalk,
		Visible: true, Carrying: -1, CarriedBy: -1, RescueSlot: -1, CarrySaved: -1,
		Facing: Vec{0, 1},
	}
	if slot == SlotBoss {
		a.Kind = KindBoss
		a.Pos = office.Points["boss_spawn"]
	} else {
		a.Pos = office.SeatForSlot(slot)
		a.State = StateWork
		a.OccupyID = "seat_" + strconv.Itoa(EmployeeIndex(slot)+1)
		a.LastSeat = EmployeeIndex(slot) + 1
		office.TakeSpot(a.OccupyID, slot)
	}
	return a
}

func (a *Actor) IsBot() bool { return a.Peer == 0 }

func (a *Actor) ApplyInput(in Input) {
	a.In = Vec{in.DX, in.DY}
	if in.Interact {
		a.WantInteract = true
	}
	if in.Slack {
		a.WantSlack = true
	}
	if in.Meeting {
		a.WantMeeting = true
	}
	if in.KPI {
		a.WantKPI = true
	}
	if in.Dash {
		a.WantDash = true
	}
}

func (a *Actor) Tick(m *Match, dt float64) {
	a.CarryRecov = maxf(0, a.CarryRecov-dt)
	if a.BikeLeft > 0 {
		a.BikeLeft = maxf(0, a.BikeLeft-dt)
		if a.BikeLeft <= 0 {
			m.ClearBike(a)
		}
	}
	a.StandLock = maxf(0, a.StandLock-dt)
	a.CatchChain = maxf(0, a.CatchChain-dt)
	a.CoffeeBuff = maxf(0, a.CoffeeBuff-dt)
	a.BoostLeft = maxf(0, a.BoostLeft-dt)
	a.MeetingCD = maxf(0, a.MeetingCD-dt)
	a.KPICD = maxf(0, a.KPICD-dt)
	a.DashCD = maxf(0, a.DashCD-dt)
	a.DashLeft = maxf(0, a.DashLeft-dt)
	a.KPIFlash = maxf(0, a.KPIFlash-dt)
	if a.Kind == KindBoss {
		a.bossTick(m, dt)
	} else {
		a.employeeTick(m, dt)
	}
	a.WantInteract = false
	a.WantSlack = false
	a.WantMeeting = false
	a.WantKPI = false
	a.WantDash = false
}

func (a *Actor) employeeTick(m *Match, dt float64) {
	if a.CarriedBy >= 0 {
		if c := m.Actors[a.CarriedBy]; c != nil {
			a.Pos = c.Pos
			a.Vel = Vec{}
			if a.WantInteract && !a.IsBot() && c.CarryWindup <= 0 {
				m.ReleaseCarry(c, false)
			}
		}
		return
	}
	if a.Carrying >= 0 {
		a.CarryLeft -= dt
		a.CarryWindup = maxf(0, a.CarryWindup-dt)
		if a.State != StateWalk || a.Hours <= 0 {
			m.ReleaseCarry(a, true)
		} else if a.CarryLeft <= 0 || (a.WantInteract && a.CarryWindup <= 0) {
			m.ReleaseCarry(a, false)
			a.WantInteract = false
		} else {
			speed := EmployeeSpeed * 0.88
			if a.CarryWindup <= 0 {
				a.Vel = a.In.Limit(1).Mul(speed)
			} else {
				a.Vel = Vec{}
			}
			a.slide(m, dt)
		}
		return
	}
	if a.State == StateLeft {
		a.Visible = false
		a.Vel = Vec{}
		return
	}
	if a.Hours <= 0 && a.State != StateClocking && a.State != StateTalk {
		a.beginClocking(m)
	}
	switch a.State {
	case StateTalk:
		a.tickTalk(m, dt)
		return
	case StateMeeting:
		a.MeetingLeft -= dt
		a.Energy = maxf(0, a.Energy-MeetingEnergyPerSec*dt)
		a.Vel = Vec{}
		if a.MeetingLeft <= 0 {
			a.State = StateWalk
		}
		return
	case StateClocking:
		target := m.Office.NearestPunch(a.Pos)
		blocked := m.Office.NearestDoor(a.Pos, 56)
		if blocked != nil && blocked.Closed {
			m.Office.TryDoor(a.Kind, a.Pos)
		}
		speed := EmployeeSpeed
		if a.BikeLeft > 0 {
			speed *= BikeSpeedMul
		}
		a.moveTowards(m, m.Office.PathTo(a.Pos, target), speed, dt)
		if a.Pos.Dist(target) < ClockRange {
			a.clockOut(m)
		}
		return
	case StateWork:
		if a.WantSlack {
			a.State = StateSlack
			a.sitWork(m, dt, true)
			return
		}
		if a.WantInteract || a.In.Len() > 0.12 {
			a.standUp(m)
			if a.WantInteract {
				m.TryRescue(a)
				return
			}
		} else {
			a.sitWork(m, dt, false)
			return
		}
	case StateSlack:
		if a.WantSlack {
			a.State = StateWork
			a.sitWork(m, dt, false)
			return
		}
		if a.WantInteract || a.In.Len() > 0.12 {
			a.standUp(m)
			if a.WantInteract {
				m.TryRescue(a)
				return
			}
		} else {
			a.sitWork(m, dt, true)
			return
		}
	case StateCoffee:
		a.Energy = minf(EnergyMax, a.Energy+CoffeeEnergyPerSec*dt)
		a.Vel = Vec{}
		if a.Energy >= EnergyMax-0.2 || a.WantInteract || a.In.Len() > 0.12 {
			a.CoffeeBuff = CoffeeBuffTime
			a.standUp(m)
		} else {
			return
		}
	case StateToilet:
		a.Energy = minf(EnergyMax, a.Energy+ToiletEnergyPerSec*dt)
		a.Vel = Vec{}
		if a.Energy >= EnergyMax-0.2 || a.WantInteract || a.In.Len() > 0.12 {
			a.standUp(m)
		} else {
			return
		}
	}
	if a.RescueLeft > 0 {
		if a.In.Len() > 0.12 {
			a.ClearRescue()
		} else if m.TickRescue(a, dt) {
			a.Vel = Vec{}
			return
		}
	}
	speed := EmployeeSpeed
	if a.BoostLeft > 0 {
		speed *= RescueBoostMul
	}
	if a.BikeLeft > 0 {
		speed *= BikeSpeedMul
	}
	if a.IsBot() {
		if a.In.Len() > 0.1 {
			a.Vel = a.In.Normalized().Mul(speed)
		} else {
			a.Vel = Vec{}
		}
	} else {
		a.Vel = a.In.Limit(1).Mul(speed)
	}
	a.slide(m, dt)
	if a.Vel.Len() > 8 {
		a.Facing = a.Vel.Normalized()
	}
	if a.WantInteract {
		a.tryEmployeeInteract(m)
	}
}

func (a *Actor) sitWork(m *Match, dt float64, slack bool) {
	a.Vel = Vec{}
	sup := m.IsSupervised(a)
	if slack {
		a.Energy = minf(EnergyMax, a.Energy+SlackEnergyPerSec*dt)
		if sup {
			a.SlackSeen += dt
			if a.SlackSeen >= SlackCatchDelay {
				m.CatchEmployee(a)
			}
		} else {
			a.SlackSeen = 0
		}
		return
	}
	mul := 1.0
	if a.CoffeeBuff > 0 {
		mul *= CoffeeBuffMul
	}
	if sup {
		mul *= TigerSuperviseMul
	}
	if a.Energy <= 0 {
		a.Hours = maxf(0, a.Hours-EmptyHoursPerSec*dt)
	} else {
		a.Hours = maxf(0, a.Hours-WorkHoursPerSec*mul*dt)
		a.Energy = maxf(0, a.Energy-WorkEnergyPerSec*dt)
	}
}

func (a *Actor) tryEmployeeInteract(m *Match) {
	if a.StandLock > 0 {
		return
	}
	if m.TryCarry(a) {
		return
	}
	if m.TryRescue(a) {
		return
	}
	if m.Office.TryDoor(a.Kind, a.Pos) {
		return
	}
	seat := m.Office.NearestSpot("seat", a.Pos, InteractRange)
	if seat != "" {
		if m.Office.TakeSpot(seat, a.Slot) {
			a.dismountBike(m)
			a.State = StateWork
			a.Pos = m.Office.Points[seat]
			a.OccupyID = seat
			if i := strings.TrimPrefix(seat, "seat_"); i != seat {
				n, _ := strconv.Atoi(i)
				a.LastSeat = n
			}
		}
		return
	}
	coffee := m.Office.NearestFree("coffee", a.Pos)
	if coffee != "" && a.Pos.Dist(m.Office.Points[coffee]) < InteractRange {
		if m.Office.TakeSpot(coffee, a.Slot) {
			a.dismountBike(m)
			a.OccupyID = coffee
			a.State = StateCoffee
			a.Pos = m.Office.Points[coffee]
		}
		return
	}
	toilet := m.Office.NearestFree("toilet", a.Pos)
	if toilet != "" && a.Pos.Dist(m.Office.Points[toilet]) < InteractRange {
		if m.Office.TakeSpot(toilet, a.Slot) {
			a.dismountBike(m)
			a.OccupyID = toilet
			a.State = StateToilet
			a.Pos = m.Office.Points[toilet]
		}
		return
	}
	m.TryBike(a)
}

func (a *Actor) standUp(m *Match) {
	m.Office.FreeSpot(a.OccupyID, a.Slot)
	a.OccupyID = ""
	a.State = StateWalk
	a.SlackSeen = 0
}

func (a *Actor) beginClocking(m *Match) {
	a.standUp(m)
	a.Hours = 0
	a.State = StateClocking
}

func (a *Actor) clockOut(m *Match) {
	a.dismountBike(m)
	a.State = StateLeft
	a.Visible = false
	m.OnClockOut(a.Slot)
}

func (a *Actor) tickTalk(m *Match, dt float64) {
	a.Vel = Vec{}
	dur := TalkAloneTime
	if m.IsWatched(a) {
		dur = TalkWatchTime
	}
	a.TalkProg = minf(1, a.TalkProg+dt/dur)
	if a.TalkProg >= 1 {
		m.FinishTalk(a)
	}
}

func (a *Actor) BeginTalk(m *Match) {
	m.ReleaseActorCarry(a, true)
	a.dismountBike(m)
	a.standUp(m)
	a.State = StateTalk
	a.TalkProg = 0
	a.ClearRescue()
}

func (a *Actor) EndTalkRescued() {
	a.State = StateWalk
	a.TalkProg = 0
	a.SlackSeen = 0
}

func (a *Actor) ClearRescue() {
	a.RescueLeft = 0
	a.RescueSlot = -1
}

func (a *Actor) ApplyCatch(m *Match, repeat bool) {
	if a.State == StateClocking || a.State == StateLeft {
		return
	}
	add := CatchHoursFirst
	if repeat {
		add = CatchHoursRepeat
	}
	a.dismountBike(m)
	a.standUp(m)
	a.Hours += add
	a.StandLock = CatchStandLock
	a.CatchChain = CatchChainWindow
	a.SlackSeen = 0
	a.TalkProg = 0
	a.RescueLeft = 0
	a.RescueSlot = -1
}

func (a *Actor) SendToMeeting(m *Match, seconds float64, pos Vec) {
	m.ReleaseActorCarry(a, true)
	if a.State == StateClocking || a.State == StateLeft {
		return
	}
	a.dismountBike(m)
	a.standUp(m)
	a.State = StateMeeting
	a.MeetingLeft = seconds
	a.TalkProg = 0
	a.ClearRescue()
	a.Pos = pos
}

func (a *Actor) bossTick(m *Match, dt float64) {
	speed := BossBaseSpeed * TigerSpeedMul
	if a.DashLeft > 0 {
		speed = TigerDashSpeed
	}
	if a.WantDash && a.DashCD <= 0 {
		a.DashLeft = TigerDashTime
		a.DashCD = TigerDashCD
	}
	a.Vel = a.In.Limit(1).Mul(speed)
	a.slide(m, dt)
	if a.Vel.Len() > 8 {
		a.Facing = a.Vel.Normalized()
	}
	if a.WantInteract {
		if !m.TryCatch(a) {
			m.Office.TryDoor(a.Kind, a.Pos)
		}
	}
	stuck := m.Office.NearestDoor(a.Pos, 52)
	if stuck != nil && stuck.Closed {
		m.Office.TryDoor(a.Kind, a.Pos)
	}
	if a.WantMeeting && a.MeetingCD <= 0 {
		if m.TryMeeting(a) {
			a.MeetingCD = TigerMeetingCD
		}
	}
	if a.WantKPI && a.KPICD <= 0 && m.Elapsed >= KPIUnlock {
		m.CastKPI()
		a.KPICD = KPICD
		a.KPIFlash = 1.6
	}
}

func (a *Actor) slide(m *Match, dt float64) {
	a.Pos = m.Office.MoveSlide(a.Pos, a.Vel.Mul(dt), ActorRadius)
}

func (a *Actor) moveTowards(m *Match, target Vec, speed, dt float64) {
	d := target.Sub(a.Pos)
	if d.Len() < 4 {
		a.Vel = Vec{}
		return
	}
	a.Vel = d.Normalized().Mul(speed)
	a.slide(m, dt)
	a.Facing = a.Vel.Normalized()
}

func (a *Actor) dismountBike(m *Match) {
	if a.BikeLeft > 0 {
		a.BikeLeft = 0
		if m != nil {
			m.ClearBike(a)
		}
	}
}

func maxf(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}

func minf(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}
