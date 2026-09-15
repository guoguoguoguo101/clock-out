package protocol

import "testing"

func TestEncodeDecodeRoundTrip(t *testing.T) {
	src := Message{Type: TypeCreateRoom, Name: "玩家", Short: true}
	raw, err := Encode(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw) < 4 {
		t.Fatal("missing length prefix")
	}
	got, err := Decode(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.Type != TypeCreateRoom || got.Name != "玩家" || !got.Short {
		t.Fatalf("round trip mismatch: %+v", got)
	}
}

func TestEventKeepsBossSlotZero(t *testing.T) {
	raw, err := Encode(Message{Type: TypeEvent, Event: &Event{Kind: "catch", Slot: 0, Repeat: true}})
	if err != nil {
		t.Fatal(err)
	}
	got, err := Decode(raw)
	if err != nil {
		t.Fatal(err)
	}
	if got.Event == nil || got.Event.Slot != 0 || got.Event.Kind != "catch" {
		t.Fatalf("slot 0 dropped: %+v", got.Event)
	}
}
