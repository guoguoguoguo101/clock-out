extends Node

signal status_changed
signal peer_list_changed
signal room_list_changed
signal room_ready
signal go_error

const PORT := 27111
const MAX_CLIENTS := 8

var is_server := false
var is_dedicated := false
var connected := false
var last_error := ""
var listen_port := PORT

var using_go := false
var local_test := false
var go_peer_id := 0
var room_code := ""
var captain_id := 0
var rooms: Array = []

var _ws: WebSocketPeer
var _ws_host := "127.0.0.1"
var _opened := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(true)


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _opened:
			_opened = true
			using_go = true
			_send({"type": "hello"})
		while _ws.get_available_packet_count() > 0:
			_on_packet(_ws.get_packet())
	elif st == WebSocketPeer.STATE_CLOSING:
		pass
	elif st == WebSocketPeer.STATE_CLOSED:
		if using_go or connected:
			if not _opened:
				last_error = "连不上服务器，确认已启动 server.bat"
			else:
				last_error = "与服务器断开"
			_reset_go()
			status_changed.emit()


func host_listen() -> Error:
	return _start_server(false)


func host_dedicated() -> Error:
	return _start_server(true)


func _start_server(dedicated: bool) -> Error:
	var err := ERR_CANT_CREATE
	var port := PORT
	var peer: ENetMultiplayerPeer = null
	for i in 8:
		peer = ENetMultiplayerPeer.new()
		err = peer.create_server(port, MAX_CLIENTS)
		if err == OK:
			break
		port += 1
	if err != OK or peer == null:
		last_error = "开服失败（%d 起端口被占用）" % PORT
		return err
	multiplayer.multiplayer_peer = peer
	is_server = true
	is_dedicated = dedicated
	connected = true
	listen_port = port
	last_error = ""
	print("[Net] server listening on %d dedicated=%s" % [port, dedicated])
	status_changed.emit()
	peer_list_changed.emit()
	return OK


func join(ip: String) -> Error:
	return connect_go(ip)


func connect_go(ip: String) -> Error:
	leave()
	_ws_host = ip.strip_edges()
	if _ws_host == "":
		_ws_host = "127.0.0.1"
	_ws = WebSocketPeer.new()
	var url := "ws://%s:%d/" % [_ws_host, PORT]
	var err := _ws.connect_to_url(url)
	if err != OK:
		last_error = "连接失败"
		_ws = null
		return err
	using_go = true
	connected = false
	_opened = false
	last_error = "正在连接 %s …" % url
	print("[Net] joining go %s" % url)
	status_changed.emit()
	return OK


func create_room() -> void:
	_send({"type": "create_room"})


func join_room(code: String) -> void:
	_send({"type": "join_room", "code": code.strip_edges().to_upper()})


func list_rooms() -> void:
	_send({"type": "list_rooms"})


func leave_room() -> void:
	_send({"type": "leave_room"})
	room_code = ""
	captain_id = 0


func claim(slot: int, player_name: String) -> void:
	_send({"type": "claim", "slot": slot, "name": player_name})


func set_bot(slot: int, on: bool) -> void:
	_send({"type": "bot_slot", "slot": slot, "on": on})


func fill_bots() -> void:
	_send({"type": "fill_bots"})


func start_match(p_short: bool) -> void:
	_send({"type": "start", "short": p_short})


func reset_match() -> void:
	_send({"type": "reset"})


func send_input(dx: float, dy: float, interact: bool, slack: bool, meeting: bool, kpi: bool, dash: bool, fly := false, incident := false, blame := false) -> void:
	_send({
		"type": "input",
		"dx": dx,
		"dy": dy,
		"interact": interact,
		"slack": slack,
		"meeting": meeting,
		"kpi": kpi,
		"dash": dash,
		"fly": fly,
		"incident": incident,
		"blame": blame,
	})


func is_captain() -> bool:
	return using_go and go_peer_id != 0 and go_peer_id == captain_id


func go_match() -> bool:
	return using_go and not local_test


func begin_local_test() -> void:
	local_test = true


func end_local_test() -> void:
	local_test = false


func has_peer() -> bool:
	return multiplayer.multiplayer_peer != null


func is_enet_server() -> bool:
	return not go_match() and has_peer() and multiplayer.is_server()


func leave() -> void:
	if _ws != null:
		_ws.close()
		_ws = null
	local_test = false
	_reset_go()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_server = false
	is_dedicated = false
	connected = false
	status_changed.emit()
	peer_list_changed.emit()


func _reset_go() -> void:
	_ws = null
	_opened = false
	using_go = false
	go_peer_id = 0
	room_code = ""
	captain_id = 0
	connected = false
	rooms = []


func peer_ids() -> Array[int]:
	var ids: Array[int] = []
	if go_match():
		if go_peer_id != 0:
			ids.append(go_peer_id)
		return ids
	if multiplayer.multiplayer_peer == null:
		return ids
	ids.append(multiplayer.get_unique_id())
	for id in multiplayer.get_peers():
		ids.append(int(id))
	ids.sort()
	return ids


func _send(data: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var body := JSON.stringify(data).to_utf8_buffer()
	var n := body.size()
	var out := PackedByteArray()
	out.resize(4 + n)
	out[0] = (n >> 24) & 255
	out[1] = (n >> 16) & 255
	out[2] = (n >> 8) & 255
	out[3] = n & 255
	for i in n:
		out[4 + i] = body[i]
	_ws.put_packet(out)


func _on_packet(raw: PackedByteArray) -> void:
	if raw.size() < 4:
		return
	var buf := StreamPeerBuffer.new()
	buf.big_endian = true
	buf.data_array = raw
	var n := int(buf.get_u32())
	if n <= 0 or n > raw.size() - 4:
		return
	var text := raw.slice(4, 4 + n).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_handle(parsed)


func _handle(msg: Dictionary) -> void:
	var typ := str(msg.get("type", ""))
	match typ:
		"welcome":
			go_peer_id = int(msg.get("peer", 0))
			connected = true
			last_error = ""
			print("[Net] go welcome peer=%d" % go_peer_id)
			status_changed.emit()
		"room_ready":
			room_code = str(msg.get("code", ""))
			captain_id = int(msg.get("captain", 0))
			last_error = ""
			if not local_test:
				room_ready.emit()
			status_changed.emit()
		"room_list":
			rooms = msg.get("rooms", [])
			room_list_changed.emit()
		"lobby":
			var lobby: Dictionary = msg.get("lobby", {})
			captain_id = int(msg.get("captain", lobby.get("captain", captain_id)))
			room_code = str(msg.get("code", lobby.get("code", room_code)))
			if Match and not local_test:
				Match.apply_go_lobby(lobby, captain_id)
			if not local_test:
				status_changed.emit()
		"snapshot":
			if local_test:
				return
			var snap: Dictionary = msg.get("snapshot", {})
			if Match:
				Match.apply_go_snapshot(snap)
		"event":
			if local_test:
				return
			var ev: Dictionary = msg.get("event", {})
			if Match:
				Match.apply_go_event(ev)
		"error":
			last_error = str(msg.get("reason", "错误"))
			go_error.emit()
			status_changed.emit()


func _on_peer_connected(id: int) -> void:
	print("[Net] peer in %d" % id)
	peer_list_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	print("[Net] peer out %d" % id)
	peer_list_changed.emit()


func _on_connected() -> void:
	connected = true
	last_error = ""
	print("[Net] connected id=%d" % multiplayer.get_unique_id())
	status_changed.emit()
	peer_list_changed.emit()


func _on_connect_failed() -> void:
	connected = false
	last_error = "连不上服务器，确认服务端已启动"
	leave()


func _on_server_disconnected() -> void:
	last_error = "与服务器断开"
	leave()
