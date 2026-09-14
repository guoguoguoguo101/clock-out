extends Node

signal status_changed
signal peer_list_changed

const PORT := 27111
const MAX_CLIENTS := 8

var is_server := false
var is_dedicated := false
var connected := false
var last_error := ""
var listen_port := PORT


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


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
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), PORT)
	if err != OK:
		last_error = "连接失败"
		return err
	multiplayer.multiplayer_peer = peer
	is_server = false
	is_dedicated = false
	connected = false
	last_error = "正在连接 %s:%d …" % [ip, PORT]
	print("[Net] joining %s:%d" % [ip, PORT])
	status_changed.emit()
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_server = false
	is_dedicated = false
	connected = false
	status_changed.emit()
	peer_list_changed.emit()


func peer_ids() -> Array[int]:
	var ids: Array[int] = []
	if multiplayer.multiplayer_peer == null:
		return ids
	ids.append(multiplayer.get_unique_id())
	for id in multiplayer.get_peers():
		ids.append(int(id))
	ids.sort()
	return ids


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
