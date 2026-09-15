package sim

type BossBot struct {
	Actor    *Actor
	Map      *Office
	Match    *Match
	Patrol   int
	Wait     float64
	Watching bool
}

func (b *BossBot) Tick(dt float64) {
	a := b.Actor
	b.Wait -= dt
	door := b.Map.NearestDoor(a.Pos, 70)
	if door != nil && (door.Closed || door.Opening) {
		dd := door.Pos.Sub(a.Pos)
		if dd.Len() > 10 {
			a.In = dd.Normalized()
		} else {
			a.In = Vec{}
		}
		if door.Closed {
			a.WantInteract = true
		}
		return
	}
	if talk := b.talkHere(); talk != nil {
		if b.Watching {
			a.In = Vec{}
			if b.Wait <= 0 {
				b.Watching = false
			}
			return
		}
		if b.Wait <= 0 {
			b.Watching = true
			b.Wait = 3.4
			a.In = Vec{}
			return
		}
	} else {
		b.Watching = false
	}
	if prey := b.findPrey(); prey != nil {
		d := prey.Pos.Sub(a.Pos)
		a.In = d.Normalized()
		if d.Len() < CatchRange+8 {
			a.WantInteract = true
		}
		if b.Wait <= 0 && d.Len() < 260 {
			a.WantMeeting = true
			b.Wait = 4
		}
		return
	}
	spots := []Vec{
		b.Map.Points["sup_1"], b.Map.Points["coffee_0"], b.Map.Points["sup_3"],
		b.Map.Points["punch_0"], b.Map.Points["toilet_0"], b.Map.Points["sup_2"],
	}
	target := spots[b.Patrol%len(spots)]
	d2 := b.Map.PathTo(a.Pos, target).Sub(a.Pos)
	if d2.Len() > 12 {
		a.In = d2.Normalized()
	} else {
		a.In = Vec{}
	}
	if d2.Len() < 18 {
		b.Patrol++
	}
	if b.Match.Elapsed > KPIUnlock+2 && a.KPICD <= 0 && b.Wait <= 0 {
		a.WantKPI = true
		b.Wait = 8
	}
	if b.Match.Elapsed > IncidentUnlock+5 && a.IncidentCD <= 0 && !b.Match.IncidentActive && b.Wait <= 0 {
		a.WantIncident = true
		b.Wait = 12
	}
}

func (b *BossBot) talkHere() *Actor {
	for _, e := range b.Match.Actors {
		if e.Kind != KindEmployee || e.State != StateTalk {
			continue
		}
		if b.Map.SameView(b.Actor.Pos, e.Pos) {
			return e
		}
	}
	return nil
}

func (b *BossBot) findPrey() *Actor {
	var best *Actor
	bestD := 220.0
	for _, e := range b.Match.Actors {
		if e.Kind != KindEmployee {
			continue
		}
		if e.State != StateSlack && e.State != StateCoffee && e.State != StateToilet {
			continue
		}
		d := e.Pos.Dist(b.Actor.Pos)
		if d < bestD {
			bestD = d
			best = e
		}
	}
	return best
}

type EmployeeBot struct {
	Actor *Actor
	Map   *Office
	Match *Match
	Think float64
}

func (b *EmployeeBot) Tick(dt float64) {
	a := b.Actor
	if a.CarriedBy >= 0 {
		a.In = Vec{}
		a.WantInteract = false
		return
	}
	if a.State == StateLeft || a.State == StateClocking || a.State == StateMeeting || a.State == StateTalk {
		a.In = Vec{}
		return
	}
	b.Think -= dt
	if a.RescueLeft > 0 {
		a.In = Vec{}
		return
	}
	if a.State == StateCoffee || a.State == StateToilet {
		if a.Energy > 92 {
			a.WantInteract = true
		}
		return
	}
	if a.State == StateWork {
		if a.Energy < 18 {
			a.WantInteract = true
		} else if a.Energy < 40 && b.Think <= 0 {
			a.WantSlack = true
			b.Think = 2
		}
		return
	}
	if a.State == StateSlack {
		if a.Energy > 78 {
			a.WantSlack = true
		}
		return
	}
	blocked := b.Map.NearestDoor(a.Pos, 56)
	if blocked != nil && blocked.Closed {
		b.goTo(blocked.Pos)
		a.WantInteract = true
		return
	}
	if vic := b.findRescue(); vic != nil {
		b.goTo(vic.Pos)
		if a.Pos.Dist(vic.Pos) < RescueRange {
			a.WantInteract = true
		}
		return
	}
	if a.Energy < 22 {
		id := b.Map.NearestFree("coffee", a.Pos)
		if id == "" {
			id = b.Map.NearestFree("toilet", a.Pos)
		}
		if id != "" {
			b.goTo(b.Map.Points[id])
			if a.Pos.Dist(b.Map.Points[id]) < InteractRange {
				a.WantInteract = true
			}
			return
		}
	}
	seat := b.Map.NearestFree("seat", a.Pos)
	if seat == "" {
		b.goTo(b.Map.Points["corridor"])
		return
	}
	b.goTo(b.Map.Points[seat])
	if a.Pos.Dist(b.Map.Points[seat]) < InteractRange && a.StandLock <= 0 {
		a.WantInteract = true
	}
}

func (b *EmployeeBot) goTo(target Vec) {
	next := b.Map.PathTo(b.Actor.Pos, target)
	d := next.Sub(b.Actor.Pos)
	if d.Len() > 6 {
		b.Actor.In = d.Normalized()
	} else {
		b.Actor.In = Vec{}
	}
}

func (b *EmployeeBot) findRescue() *Actor {
	a := b.Actor
	if a.Energy < 26 || a.Hours < 14 {
		return nil
	}
	var best *Actor
	bestD := 520.0
	for _, e := range b.Match.Actors {
		if e == a || e.Kind != KindEmployee || e.State != StateTalk {
			continue
		}
		if b.Match.IsWatched(e) {
			continue
		}
		d := a.Pos.Dist(e.Pos)
		if d < bestD {
			bestD = d
			best = e
		}
	}
	return best
}
