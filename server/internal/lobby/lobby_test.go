package lobby

import "testing"

func TestTwoRoomsIsolated(t *testing.T) {
	l := New()
	a, err := l.Create(2)
	if err != nil {
		t.Fatal(err)
	}
	b, err := l.Create(3)
	if err != nil {
		t.Fatal(err)
	}
	if a.Code == b.Code {
		t.Fatal("codes collided")
	}
	if _, err := l.Join(4, a.Code); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Join(4, b.Code); err != ErrAlreadyIn {
		t.Fatalf("expected already in, got %v", err)
	}
	if l.RoomOf(4).Code != a.Code {
		t.Fatal("peer 4 should stay in A")
	}
}

func TestJoinBadCodeAndInProgress(t *testing.T) {
	l := New()
	r, _ := l.Create(2)
	if _, err := l.Join(3, "XXXX"); err != ErrBadCode {
		t.Fatalf("bad code: %v", err)
	}
	if _, err := l.Claim(2, 1, "A"); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Start(2, true); err != nil {
		t.Fatal(err)
	}
	if r.Match.Phase != "countdown" && r.Match.Phase != "playing" {
		t.Fatalf("phase %s", r.Match.Phase)
	}
	if _, err := l.Join(3, r.Code); err != ErrInProgress {
		t.Fatalf("expected in progress, got %v", err)
	}
}

func TestRoomFull(t *testing.T) {
	l := New()
	r, _ := l.Create(2)
	for id := 3; id <= 7; id++ {
		if _, err := l.Join(id, r.Code); err != nil {
			t.Fatalf("join %d: %v", id, err)
		}
	}
	if _, err := l.Join(8, r.Code); err != ErrRoomFull {
		t.Fatalf("expected full, got %v", err)
	}
}

func TestEmptyRoomDeleted(t *testing.T) {
	l := New()
	r, _ := l.Create(2)
	code := r.Code
	l.Leave(2)
	if l.RoomOf(2) != nil {
		t.Fatal("still in room")
	}
	for _, info := range l.List() {
		if info.Code == code {
			t.Fatal("empty room still listed")
		}
	}
}

func TestCaptainStartAndTransfer(t *testing.T) {
	l := New()
	r, _ := l.Create(5)
	if _, err := l.Join(8, r.Code); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Start(8, true); err != ErrNotCaptain {
		t.Fatalf("member started: %v", err)
	}
	l.Disconnect(5)
	r = l.RoomOf(8)
	if r == nil || r.Captain != 8 {
		t.Fatalf("captain not transferred: %+v", r)
	}
}

func TestDisconnectDuringMatchBecomesBot(t *testing.T) {
	l := New()
	r, _ := l.Create(2)
	_, _ = l.Join(3, r.Code)
	_, _ = l.Claim(2, 0, "Boss")
	_, _ = l.Claim(3, 1, "Emp")
	_, _ = l.Start(2, true)
	r.Match.Phase = "playing"
	r.Match.Playing = true
	left, slot, destroyed := l.Disconnect(3)
	if destroyed {
		t.Fatal("room should remain with remaining human")
	}
	if slot != 1 {
		t.Fatalf("converted slot %d", slot)
	}
	if left.Match.Slots[1] != 0 {
		t.Fatalf("slot peer %d", left.Match.Slots[1])
	}
}

func TestSetBotAndFill(t *testing.T) {
	l := New()
	r, _ := l.Create(2)
	if _, err := l.SetBot(2, 1, true); err != nil {
		t.Fatal(err)
	}
	if r.Match.Slots[1] != 0 {
		t.Fatalf("bot slot %d", r.Match.Slots[1])
	}
	if _, err := l.SetBot(2, 1, false); err != nil {
		t.Fatal(err)
	}
	if r.Match.Slots[1] != -1 {
		t.Fatal("bot not cleared")
	}
	if _, err := l.FillBots(2); err != nil {
		t.Fatal(err)
	}
	empty := 0
	for _, p := range r.Match.Slots {
		if p == -1 {
			empty++
		}
	}
	if empty != 0 {
		t.Fatalf("still empty %d", empty)
	}
}
