package sim

import "testing"

func TestWorkHoursRate(t *testing.T) {
	m := NewMatch()
	m.Slots[SlotEmpA] = 1
	m.Start(true, true)
	a := m.Actors[SlotEmpA]
	start := a.Hours
	a.sitWork(m, 1.0, false)
	want := start - WorkHoursPerSec
	if abs(a.Hours-want) > 1e-6 {
		t.Fatalf("hours %v want %v", a.Hours, want)
	}
	if abs(a.Energy-(EnergyStart-WorkEnergyPerSec)) > 1e-6 {
		t.Fatalf("energy %v", a.Energy)
	}
}

func TestLungeGrabsWalking(t *testing.T) {
	m := NewMatch()
	m.Slots[SlotEmpA] = 1
	m.Slots[SlotBoss] = 2
	m.Start(true, true)
	emp := m.Actors[SlotEmpA]
	boss := m.Actors[SlotBoss]
	emp.standUp(m)
	emp.Pos = m.Office.Points["corridor"]
	boss.Pos = emp.Pos.Add(Vec{-20, 0})
	boss.Facing = Vec{1, 0}
	if !m.StartLunge(boss) {
		t.Fatal("start lunge")
	}
	if m.LungeVictim(boss, boss.Pos, emp.Pos) != emp {
		t.Fatal("expected lunge hit")
	}
	m.GrabLunge(boss, emp)
	if emp.State != StateTalk {
		t.Fatalf("state %d want talk", emp.State)
	}
	if boss.PowerPips != 1 {
		t.Fatalf("power %d", boss.PowerPips)
	}
}

func TestCarryFreesSeat(t *testing.T) {
	m := NewMatch()
	m.Slots[SlotEmpA] = 1
	m.Slots[SlotEmpD] = 2
	m.Start(true, true)
	carrier := m.Actors[SlotEmpD]
	pass := m.Actors[SlotEmpA]
	carrier.standUp(m)
	carrier.Pos = m.Office.Points["corridor"]
	pass.Pos = carrier.Pos.Add(Vec{40, 0})
	seat := pass.OccupyID
	if !m.TryCarry(carrier) {
		t.Fatal("carry failed")
	}
	if m.Office.Occupiers[seat] != -1 {
		t.Fatalf("seat still occupied by %d", m.Office.Occupiers[seat])
	}
	if pass.State != StateCarried {
		t.Fatalf("passenger state %d", pass.State)
	}
}

func TestClosedDoorBlocksThenOpens(t *testing.T) {
	o := DefaultOffice()
	d := o.NearestDoor(Vec{180, 554}, 20)
	if d == nil {
		t.Fatal("missing toilet door")
	}
	d.Slam()
	if !o.CircleHits(d.Pos, ActorRadius) {
		t.Fatal("closed door should collide")
	}
	d.BeginOpen()
	d.Tick(DoorOpenTime + 0.01)
	if o.CircleHits(d.Pos, ActorRadius) {
		t.Fatal("open door should not collide")
	}
}

func TestSetBotThenStartSkipsEmpty(t *testing.T) {
	m := NewMatch()
	m.Slots[SlotEmpA] = 1
	if !m.SetBot(SlotBoss, true) {
		t.Fatal("set bot")
	}
	m.Start(true, true)
	if m.Actors[SlotBoss] == nil || m.Actors[SlotEmpA] == nil {
		t.Fatal("missing filled actors")
	}
	if m.Actors[SlotEmpB] != nil {
		t.Fatal("empty slot should not spawn")
	}
}

func TestAllPunchedIgnoresVacant(t *testing.T) {
	m := NewMatch()
	m.Slots[SlotEmpA] = 1
	m.Start(true, true)
	m.Actors[SlotEmpA].State = StateLeft
	if !m.allPunched() {
		t.Fatal("sole employee left should end match")
	}
}

func abs(v float64) float64 {
	if v < 0 {
		return -v
	}
	return v
}
