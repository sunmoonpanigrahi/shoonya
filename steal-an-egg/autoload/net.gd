extends Node
## Game sessions: solo, or same-Wi-Fi play where one phone hosts and the others join.
##
## The host runs the shared world (monsters, eggs, traps, hits). Each phone moves its
## own thief. Hosts announce themselves with a UDP broadcast so joiners can list them.

signal players_changed
signal hosts_changed
signal join_failed(reason: String)
signal session_ended(reason: String)

const WORLD_SCENE := "res://scenes/world.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const BEACON_INTERVAL := 1.0
const HOST_TIMEOUT := 4.0

## "solo", "host" or "client".
var mode := "solo"
## peer id -> {"name", "bat_level", "pet_name", "pet_element", "pet_rarity", "index"}
var players: Dictionary = {}
var world_seed := 0
var in_game := false
## Found hosts: ip -> {"name", "players", "seen"}
var hosts: Dictionary = {}
## Message shown on the main menu after a session ends.
var last_message := ""

var _beacon: PacketPeerUDP
var _listener: PacketPeerUDP
var _beacon_timer := 0.0


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
	if _listener:
		_poll_listener()


func is_online() -> bool:
	return mode != "solo"


func my_id() -> int:
	return multiplayer.get_unique_id()


func player_index(peer_id: int) -> int:
	return int(players.get(peer_id, {}).get("index", 0))


# --- Starting sessions -------------------------------------------------------

## Sets up a one-player session without changing scene (the world scene calls this when run directly).
func setup_solo() -> void:
	_close_peer()
	mode = "solo"
	players = {1: _with_index(SaveGame.player_info(), 0)}
	world_seed = randi()


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
	players = {1: _with_index(SaveGame.player_info(), 0)}
	_start_beacon()
	players_changed.emit()
	return OK


func join_game(address: String) -> Error:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), GameData.LAN_GAME_PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	in_game = false
	players = {}
	return OK


## Host only: everyone loads the world.
func start_game() -> void:
	if mode != "host":
		return
	_stop_beacon()
	_start_game.rpc(randi())


func leave(message: String = "") -> void:
	last_message = message
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


func _stop_beacon() -> void:
	if _beacon:
		_beacon.close()
		_beacon = null


func _send_beacon() -> void:
	var payload := JSON.stringify({
		"game": "steal-an-egg",
		"name": players.get(1, {}).get("name", "Host"),
		"players": players.size(),
	}).to_utf8_buffer()
	var targets := PackedStringArray(["255.255.255.255"])
	for address in local_addresses():
		var parts := address.split(".")
		targets.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for target in targets:
		_beacon.set_dest_address(target, GameData.LAN_DISCOVERY_PORT)
		_beacon.put_packet(payload)


func _poll_listener() -> void:
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var packet := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if parsed is Dictionary and parsed.get("game") == "steal-an-egg":
			hosts[ip] = {"name": str(parsed.get("name", "Host")), "players": int(parsed.get("players", 1)),
				"seen": Time.get_ticks_msec()}
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

func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		_sync_players.rpc(players)


func _on_connected_to_server() -> void:
	_register.rpc_id(1, SaveGame.player_info())


func _on_connection_failed() -> void:
	_close_peer()
	mode = "solo"
	join_failed.emit("Could not reach the host. Check that both phones are on the same Wi-Fi.")


func _on_server_disconnected() -> void:
	leave("The host ended the game.")


@rpc("any_peer", "reliable")
func _register(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if in_game or players.size() >= GameData.MAX_PLAYERS:
		_rejected.rpc_id(sender, "That game is already running or full.")
		return
	var used := []
	for p in players.values():
		used.append(p["index"])
	var index := 0
	while index in used:
		index += 1
	players[sender] = _with_index(_clean_info(info), index)
	_sync_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func _sync_players(all_players: Dictionary) -> void:
	players = all_players
	players_changed.emit()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	join_failed.emit(reason)
	_close_peer()
	mode = "solo"


@rpc("authority", "call_local", "reliable")
func _start_game(seed_value: int) -> void:
	world_seed = seed_value
	_enter_world()


func _enter_world() -> void:
	in_game = true
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
	}


func _close_peer() -> void:
	_stop_beacon()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
