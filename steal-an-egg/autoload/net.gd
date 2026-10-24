extends Node
## Game sessions: solo, or same-Wi-Fi play where one phone hosts and the others join.
##
## The host runs the shared world (monsters, eggs, traps, hits). Each phone moves its
## own thief. Players can join a game that is already running, and a phone that loses
## its connection rejoins by itself.
##
## Finding hosts: the host broadcasts "here I am" every second, and joiners also ask
## every address on their Wi-Fi directly. Many Android phones drop broadcasts, but
## always receive direct replies.

signal players_changed
signal hosts_changed
signal join_failed(reason: String)
## Host only: a player joined or left (also mid-game).
signal player_joined(peer_id: int)

const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const BEACON_INTERVAL := 1.0
const PROBE_INTERVAL := 2.0
const HOST_TIMEOUT := 5.0
const PROBE_TEXT := "steal-an-egg?"

## "solo", "host" or "client".
var mode := "solo"
## peer id -> {"name", "bat_level", "pet_name", "pet_element", "pet_rarity", "crown", "index"}
var players: Dictionary = {}
var world_seed := 0
var in_game := false
## True from asking to join until the host answers or the attempt fails.
var connecting := false
## Found hosts: ip -> {"name", "players", "in_game", "seen"}
var hosts: Dictionary = {}
## Message shown on the next screen after a session ends or drops.
var last_message := ""
## Host address to rejoin by itself after a dropped connection (empty when not rejoining).
var rejoin_address := ""

var _last_host_address := ""
var _host_ended := false
## Set while this phone closes its own connection, so that isn't mistaken for a drop.
var _closing := false
var _beacon: PacketPeerUDP
var _probe_listener: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_timer := 0.0
var _probe_timer := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	if _beacon:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = BEACON_INTERVAL
			_send_beacon()
		_answer_probes()
	if _listener:
		_probe_timer -= delta
		if _probe_timer <= 0.0:
			_probe_timer = PROBE_INTERVAL
			_send_probes()
		_poll_listener()


func is_online() -> bool:
	return mode != "solo"


func my_id() -> int:
	return multiplayer.get_unique_id()


func player_index(peer_id: int) -> int:
	return int(players.get(peer_id, {}).get("index", 0))


# --- Starting and ending sessions ---------------------------------------------

## Sets up a one-player session without changing scene (the world scene calls this when run directly).
func setup_solo() -> void:
	_close_peer()
	mode = "solo"
	players = {1: _with_index(_clean_info(SaveGame.player_info()), 0)}
	world_seed = randi()
	rejoin_address = ""


func start_solo() -> void:
	setup_solo()
	_enter_world()


func host_game() -> Error:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(GameData.LAN_GAME_PORT, GameData.MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	in_game = false
	rejoin_address = ""
	players = {1: _with_index(_clean_info(SaveGame.player_info()), 0)}
	_start_beacon()
	players_changed.emit()
	return OK


func join_game(address: String) -> Error:
	_close_peer()
	address = address.strip_edges()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, GameData.LAN_GAME_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	in_game = false
	connecting = true
	_host_ended = false
	_last_host_address = address
	players = {}
	return OK


## Host only: everyone loads the world. Players can still join afterwards.
func start_game() -> void:
	if mode != "host":
		return
	_start_game.rpc(randi())


## Ends the session and returns to the main menu. A host tells everyone first, so
## their phones don't try to rejoin a game that is over.
func leave(message: String = "") -> void:
	if mode == "host" and not players.is_empty():
		_host_ending.rpc()
		# Give the goodbye a moment to go out before the connection closes.
		await get_tree().create_timer(0.3).timeout
	last_message = message
	rejoin_address = ""
	_close_peer()
	stop_discovery()
	mode = "solo"
	players = {}
	in_game = false
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Finding hosts on the same Wi-Fi -------------------------------------------

func start_discovery() -> void:
	stop_discovery()
	hosts.clear()
	_listener = PacketPeerUDP.new()
	if _listener.bind(GameData.LAN_DISCOVERY_PORT) != OK:
		_listener = null
	_probe_timer = 0.0


func stop_discovery() -> void:
	if _listener:
		_listener.close()
		_listener = null


## Private IPv4 addresses of this phone, to show on the host screen.
func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or _is_172_private(address):
			out.append(address)
	return out


func _start_beacon() -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_timer = 0.0
	_probe_listener = PacketPeerUDP.new()
	if _probe_listener.bind(GameData.LAN_PROBE_PORT) != OK:
		_probe_listener = null


func _stop_beacon() -> void:
	if _beacon:
		_beacon.close()
		_beacon = null
	if _probe_listener:
		_probe_listener.close()
		_probe_listener = null


func _beacon_payload() -> PackedByteArray:
	return JSON.stringify({
		"game": "steal-an-egg",
		"name": players.get(1, {}).get("name", "Host"),
		"players": players.size(),
		"in_game": in_game,
	}).to_utf8_buffer()


func _send_beacon() -> void:
	var payload := _beacon_payload()
	var targets := PackedStringArray(["255.255.255.255"])
	for address in local_addresses():
		var parts := address.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for target in targets:
		_beacon.set_dest_address(target, GameData.LAN_DISCOVERY_PORT)
		_beacon.put_packet(payload)


## Host: answer joiners that ask directly.
func _answer_probes() -> void:
	if _probe_listener == null:
		return
	while _probe_listener.get_available_packet_count() > 0:
		var packet := _probe_listener.get_packet()
		if packet.get_string_from_utf8() != PROBE_TEXT:
			continue
		_probe_listener.set_dest_address(_probe_listener.get_packet_ip(), _probe_listener.get_packet_port())
		_probe_listener.put_packet(_beacon_payload())


## Joiner: ask every address on this phone's Wi-Fi whether it is hosting.
func _send_probes() -> void:
	var question := PROBE_TEXT.to_utf8_buffer()
	var targets := PackedStringArray(["127.0.0.1"])
	for address in local_addresses():
		var parts := address.split(".")
		for last in range(1, 255):
			targets.append("%s.%s.%s.%d" % [parts[0], parts[1], parts[2], last])
	for target in targets:
		_listener.set_dest_address(target, GameData.LAN_PROBE_PORT)
		_listener.put_packet(question)


func _poll_listener() -> void:
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var packet := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if parsed is Dictionary and parsed.get("game") == "steal-an-egg":
			hosts[ip] = {"name": str(parsed.get("name", "Host")), "players": int(parsed.get("players", 1)),
				"in_game": bool(parsed.get("in_game", false)), "seen": Time.get_ticks_msec()}
			changed = true
	for ip in hosts.keys():
		if Time.get_ticks_msec() - int(hosts[ip]["seen"]) > HOST_TIMEOUT * 1000.0:
			hosts.erase(ip)
			changed = true
	if changed:
		hosts_changed.emit()


func _is_172_private(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var second := address.split(".")[1].to_int()
	return second >= 16 and second <= 31


# --- Connection events and lobby RPCs ------------------------------------------

func _on_peer_connected(id: int) -> void:
	# Phones on Wi-Fi go quiet for a few seconds now and then (power saving). Wait
	# longer than the default before deciding a phone is gone.
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet:
		var packet_peer := enet.get_peer(id)
		if packet_peer:
			packet_peer.set_timeout(GameData.NET_TIMEOUT_LIMIT, GameData.NET_TIMEOUT_MIN_MS, GameData.NET_TIMEOUT_MAX_MS)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		_sync_players.rpc(players)


func _on_connected_to_server() -> void:
	_register.rpc_id(1, SaveGame.player_info())


func _on_connection_failed() -> void:
	if _closing:
		return
	_close_peer()
	connecting = false
	mode = "solo"
	join_failed.emit("Could not reach the host. Check that both phones are on the same Wi-Fi.")


func _on_server_disconnected() -> void:
	if _closing or mode != "client":
		return
	connecting = false
	if _host_ended or not in_game or _last_host_address == "":
		leave("The host ended the game." if _host_ended else "Lost the connection to the host.")
		return
	# The connection dropped mid-game: go to the lobby, which keeps trying to rejoin.
	_close_peer()
	mode = "client"
	in_game = false
	players = {}
	rejoin_address = _last_host_address
	last_message = "Lost the connection to the host. Rejoining..."
	get_tree().change_scene_to_file(LOBBY_SCENE)


@rpc("any_peer", "reliable")
func _register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.size() >= GameData.MAX_PLAYERS:
		_rejected.rpc_id(sender, "That game is full (%d players)." % GameData.MAX_PLAYERS)
		return
	var used := []
	for p in players.values():
		used.append(p["index"])
	var index := 0
	while index in used:
		index += 1
	players[sender] = _with_index(_clean_info(info), index)
	_sync_players.rpc(players)
	if in_game:
		# Joining (or rejoining) a game that is already running.
		_start_game.rpc_id(sender, world_seed)
	player_joined.emit(sender)


@rpc("authority", "call_local", "reliable")
func _sync_players(all_players: Dictionary) -> void:
	players = all_players
	connecting = false
	players_changed.emit()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	join_failed.emit(reason)
	_close_peer()
	connecting = false
	mode = "solo"


@rpc("authority", "reliable")
func _host_ending() -> void:
	_host_ended = true


@rpc("authority", "call_local", "reliable")
func _start_game(seed_value: int) -> void:
	world_seed = seed_value
	_enter_world()


func _enter_world() -> void:
	in_game = true
	rejoin_address = ""
	stop_discovery()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _with_index(info: Dictionary, index: int) -> Dictionary:
	var out := info.duplicate()
	out["index"] = index
	return out


func _clean_info(info: Dictionary) -> Dictionary:
	var element := str(info.get("pet_element", ""))
	return {
		"name": str(info.get("name", "Thief")).left(16),
		"bat_level": clampi(int(info.get("bat_level", 0)), 0, GameData.BAT_COSTS.size()),
		"pet_name": str(info.get("pet_name", "")).left(16),
		"pet_element": element if GameData.ELEMENTS.has(element) else "",
		"pet_rarity": clampi(int(info.get("pet_rarity", 0)), 0, GameData.RARITIES.size() - 1),
		"crown": bool(info.get("crown", false)),
	}


func _close_peer() -> void:
	_stop_beacon()
	_closing = true
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_closing = false
