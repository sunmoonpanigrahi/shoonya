class_name World
extends Node3D
## The game world and its rules.
##
## The host (or the only phone, in solo play) runs the rules: monsters, eggs, traps,
## bat hits and catches. Every phone moves its own thief and sends its position to the
## host; the host sends the shared state back 20 times a second.

signal message(text: String, color: Color)

const SNAPSHOT_INTERVAL := 0.05
const STATE_SEND_INTERVAL := 1.0 / 30.0
const MONSTERS_PER_PACKET := 24

var seed_value := 0
var thieves: Dictionary = {}
var monsters: Dictionary = {}
var traps: Dictionary = {}
var eggs: Array[Egg] = []
var nests: Array[Dictionary] = []
var local_thief: Thief
var camera: CameraRig
var hud: Hud
var server_time := 0.0
## Host-only: peer -> {"traps_left", "bat_ready_at", "trap_maker", "ember"}.
var players_state: Dictionary = {}
## Egg the local player lost when caught, to point the way back to it.
var lost_egg_id := -1

var _env: WorldEnvironment
var _entities: Node3D
var _incubator_pods: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _snapshot_timer := 0.0
var _send_timer := 0.0
var _pod_timer := 0.0
var _ready_peers: Dictionary = {}
var _local_traps_left := GameData.TRAPS_PER_TRIP
## Client-only: keeps telling the host it is ready until the first update arrives
## (the host may still be loading the world when the first message is sent).
var _got_snapshot := false
var _ready_timer := 0.0


func _ready() -> void:
	if Net.players.is_empty():
		Net.setup_solo()
	seed_value = Net.world_seed
	_rng.seed = seed_value
	_env = WorldBuilder.build_environment(self)
	WorldBuilder.build_ground(self)
	WorldBuilder.build_props(self, seed_value)
	nests = WorldLayout.nest_positions(seed_value)
	WorldBuilder.build_nests(self, nests)
	var base := WorldBuilder.build_base(self)
	_incubator_pods = WorldBuilder.build_incubators(base, Net.player_index(Net.my_id()))
	_entities = Node3D.new()
	_entities.name = "Entities"
	add_child(_entities)
	for i in nests.size():
		var egg := Egg.new()
		_entities.add_child(egg)
		egg.setup(i, nests[i]["biome"], nests[i]["position"], Loot.roll_rarity(nests[i]["biome"], _rng))
		eggs.append(egg)
	camera = CameraRig.new()
	add_child(camera)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if multiplayer.is_server():
		for peer in Net.players:
			_add_player(peer)
		_ready_peers.clear()
	say("Grab an egg from a nest and bring it back to your base!", Color.WHITE)


func _physics_process(delta: float) -> void:
	server_time += delta
	if local_thief:
		local_thief.local_move(delta, camera.input_yaw())
		Monster.viewer_position = local_thief.position
		WorldBuilder.update_environment(_env, local_thief.position, delta)
	for peer in thieves:
		var t: Thief = thieves[peer]
		if not t.is_local:
			t.remote_follow(delta)
	if multiplayer.is_server():
		_host_step(delta)
	else:
		if not _got_snapshot:
			_ready_timer -= delta
			if _ready_timer <= 0.0:
				_ready_timer = 0.5
				_client_ready.rpc_id(1)
		for m: Monster in monsters.values():
			m.remote_follow(delta)
		_send_timer -= delta
		if _send_timer <= 0.0 and local_thief:
			_send_timer = STATE_SEND_INTERVAL
			_thief_state.rpc_id(1, local_thief.position, local_thief.velocity, local_thief.yaw,
				local_thief.speed_t, local_thief.moving, local_thief.epoch)
	_place_carried_eggs()
	_pod_timer -= delta
	if _pod_timer <= 0.0:
		_pod_timer = 0.5
		_update_incubator_pods()


# --- Things the HUD asks for ----------------------------------------------------

func traps_left() -> int:
	if multiplayer.is_server():
		return players_state.get(Net.my_id(), {}).get("traps_left", 0)
	return _local_traps_left


func request_trap(pos: Vector3) -> void:
	if multiplayer.is_server():
		_handle_trap(Net.my_id(), pos)
	else:
		_req_trap.rpc_id(1, pos)


func request_bat() -> void:
	if multiplayer.is_server():
		_handle_bat(Net.my_id())
	else:
		_req_bat.rpc_id(1)


func egg_by_id(id: int) -> Egg:
	return eggs[id] if id >= 0 and id < eggs.size() else null


func carried_egg(peer: int) -> Egg:
	for egg in eggs:
		if egg.state == Egg.State.CARRIED and egg.carrier == peer:
			return egg
	return null


## Monsters near a position slow down for each nearby thief with an Ice pet.
func chill_factor(pos: Vector3) -> float:
	var factor := 1.0
	for t: Thief in thieves.values():
		if t.pet_element == "ice" and t.logic_position().distance_to(pos) < 20.0:
			factor *= 1.0 - GameData.perk_strength(t.pet_rarity) * 0.5
	return factor


func say(text: String, color: Color) -> void:
	message.emit(text, color)


# --- Host rules -------------------------------------------------------------------

func _host_step(delta: float) -> void:
	_step_players(delta)
	for m: Monster in monsters.values():
		var egg := egg_by_id(m.egg_id)
		var target: Thief = thieves.get(egg.carrier) if egg and egg.state == Egg.State.CARRIED else null
		if target and WorldLayout.ring_at(target.logic_position()) == 0:
			target = null
		m.server_step(delta, target, egg.position if egg else m.position, self)
	_step_traps(delta)
	_step_eggs(delta)
	_check_catches()
	for t: Thief in thieves.values():
		t.prev_logic_position = t.logic_position()
	_snapshot_timer -= delta
	if _snapshot_timer <= 0.0 and Net.is_online() and not _ready_peers.is_empty():
		_snapshot_timer = SNAPSHOT_INTERVAL
		_send_snapshot()


func _add_player(peer: int) -> void:
	var info: Dictionary = Net.players[peer]
	players_state[peer] = {"traps_left": GameData.TRAPS_PER_TRIP, "bat_ready_at": 0.0, "trap_maker": 0.0, "ember": 0.0}
	var t := _create_thief(peer)
	t.position = WorldLayout.pad_position(int(info["index"]))
	t.net_position = t.position
	t.prev_logic_position = t.position


func _create_thief(peer: int) -> Thief:
	var info: Dictionary = Net.players.get(peer, {"name": "Thief", "index": 0})
	var t := Thief.new()
	t.setup(peer, info, peer == Net.my_id())
	_entities.add_child(t)
	thieves[peer] = t
	if t.pet_element != "":
		var pet := PetFollower.new()
		_entities.add_child(pet)
		pet.setup(t, t.pet_element, t.pet_rarity)
	if t.is_local:
		local_thief = t
		camera.target = t
		camera.cam_yaw = atan2(t.position.x, t.position.z) + PI
		t.yaw = camera.cam_yaw
	return t


func _step_players(delta: float) -> void:
	for peer in thieves:
		var t: Thief = thieves[peer]
		var ps: Dictionary = players_state[peer]
		var in_base := WorldLayout.ring_at(t.logic_position()) == 0
		if in_base:
			ps["traps_left"] = GameData.TRAPS_PER_TRIP
		match t.pet_element:
			"water":
				if not in_base and ps["traps_left"] < GameData.TRAPS_PER_TRIP:
					ps["trap_maker"] += delta
					if ps["trap_maker"] >= 40.0 - 4.0 * t.pet_rarity:
						ps["trap_maker"] = 0.0
						ps["traps_left"] += 1
						_say_to(peer, "Your pet built you a new trap!", Color(0.5, 0.8, 1.0))
			"fire":
				ps["ember"] += delta
				if ps["ember"] >= 12.0:
					var hit := false
					for m: Monster in monsters.values():
						if m.is_active() and m.position.distance_to(t.logic_position()) < 12.0:
							m.stun(0.5 + 2.0 * GameData.perk_strength(t.pet_rarity), false)
							hit = true
					if hit:
						ps["ember"] = 0.0
						_say_to(peer, "Ember Burst! Your pet stunned the monsters.", Color(1.0, 0.6, 0.2))


func _step_traps(delta: float) -> void:
	for id in traps.keys():
		var trap: Trap = traps[id]
		if trap.state == Trap.State.HOLDING:
			trap.hold_left -= delta
			if trap.hold_left <= 0.0:
				if trap.victim_kind == "thief" and thieves.has(trap.victim_id):
					_broadcast_effect(trap.victim_id, "release", 0, 0)
				_remove_trap(id)
			continue
		if trap.age > GameData.TRAP_LIFETIME:
			_remove_trap(id)
			continue
		if not trap.is_armed():
			continue
		for m: Monster in monsters.values():
			if m.is_active() and CollisionMath.path_hits(m.prev_position, m.position, trap.position, GameData.TRAP_RADIUS + m.size() * 0.5):
				m.trap(trap.position)
				trap.snap("monster", m.id)
				_say_to(trap.owner_peer, "Trapped a monster for 5 seconds!", Color(0.6, 1.0, 0.6))
				break
		if trap.state == Trap.State.HOLDING:
			continue
		for peer in thieves:
			var t: Thief = thieves[peer]
			if peer == trap.owner_peer or t.fall_left > 0.0 or t.trapped_left > 0.0:
				continue
			if CollisionMath.path_hits(t.prev_logic_position, t.logic_position(), trap.position, GameData.TRAP_RADIUS):
				trap.snap("thief", peer)
				_broadcast_effect(peer, "trap", GameData.TRAP_HOLD_SECONDS, trap.position)
				var egg := carried_egg(peer)
				if egg:
					_drop_egg(egg, trap.position + Vector3(2.5, 0, 0))
				_say_to(peer, "You stepped in a trap! Stuck for 5 seconds.", Color(1.0, 0.4, 0.3))
				_say_to(trap.owner_peer, "Your trap caught %s!" % t.display_name, Color(0.6, 1.0, 0.6))
				break


func _step_eggs(delta: float) -> void:
	for egg in eggs:
		match egg.state:
			Egg.State.EMPTY:
				egg.refill_left -= delta
				if egg.refill_left <= 0.0:
					egg.set_rarity(Loot.roll_rarity(egg.biome, _rng))
					egg.position = egg.nest_position
					egg.state = Egg.State.NEST
					_egg_changed(egg)
			Egg.State.CARRIED:
				var carrier: Thief = thieves.get(egg.carrier)
				if carrier == null:
					_drop_egg(egg, egg.position)
				elif WorldLayout.ring_at(carrier.logic_position()) == 0:
					_deliver(carrier, egg)
			_:
				for peer in thieves:
					var t: Thief = thieves[peer]
					if t.carrying_egg >= 0 or not t.can_act():
						continue
					if CollisionMath.path_hits(t.prev_logic_position, t.logic_position(), egg.position, GameData.PICKUP_RADIUS):
						_pick_up(t, egg)
						break


func _pick_up(t: Thief, egg: Egg) -> void:
	var from_nest := egg.state == Egg.State.NEST
	egg.state = Egg.State.CARRIED
	egg.carrier = t.peer_id
	t.carrying_egg = egg.id
	_egg_changed(egg)
	var rarity_name: String = GameData.rarity(egg.rarity)["name"]
	if from_nest and not _has_guards(egg.id):
		var delay := 0.0
		if t.pet_element == "dark":
			delay = 1.0 + 0.5 * t.pet_rarity
		for i in int(GameData.rarity(egg.rarity)["guards"]):
			_spawn_monster(egg, delay)
	_say_to(t.peer_id, "You stole a %s egg! Run back to your base!" % rarity_name, GameData.rarity(egg.rarity)["color"])
	for peer in thieves:
		if peer != t.peer_id:
			_say_to(peer, "%s grabbed a %s egg!" % [t.display_name, rarity_name], Color(1, 0.85, 0.5))


func _spawn_monster(egg: Egg, delay: float) -> void:
	var m := Monster.new()
	m.setup(_next_id, egg.element, egg.rarity)
	_next_id += 1
	m.egg_id = egg.id
	var angle := _rng.randf() * TAU
	m.position = WorldLayout.clamp_to_world(egg.nest_position + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(14.0, 24.0))
	m.prev_position = m.position
	m.state_left = Monster.EMERGE_SECONDS + delay
	_entities.add_child(m)
	monsters[m.id] = m
	_to_ready_peers("_monster_spawned", [m.id, m.element, m.rarity, m.position])


func _remove_monster(id: int) -> void:
	if monsters.has(id):
		monsters[id].queue_free()
		monsters.erase(id)
		_to_ready_peers("_monster_removed", [id])


func _has_guards(egg_id: int) -> bool:
	for m: Monster in monsters.values():
		if m.egg_id == egg_id:
			return true
	return false


func _drop_egg(egg: Egg, pos: Vector3) -> void:
	var carrier: Thief = thieves.get(egg.carrier)
	if carrier:
		carrier.carrying_egg = -1
	egg.state = Egg.State.DROPPED
	egg.carrier = 0
	egg.position = WorldLayout.clamp_to_world(Vector3(pos.x, 0.0, pos.z))
	_egg_changed(egg)


func _deliver(t: Thief, egg: Egg) -> void:
	_send_to(t.peer_id, "_egg_delivered", [egg.rarity, egg.element])
	for id in monsters.keys():
		if monsters[id].egg_id == egg.id:
			_remove_monster(id)
	t.carrying_egg = -1
	egg.state = Egg.State.EMPTY
	egg.carrier = 0
	egg.refill_left = Loot.nest_refill_seconds(egg.biome)
	_egg_changed(egg)


func _check_catches() -> void:
	for m: Monster in monsters.values():
		if m.state != Monster.State.CHASE or not thieves.has(m.target_peer):
			continue
		var t: Thief = thieves[m.target_peer]
		if t.fall_left > 0.0 or t.carrying_egg < 0:
			continue
		var d := CollisionMath.moving_distance(m.prev_position, m.position, t.prev_logic_position, t.logic_position())
		if d <= GameData.CATCH_RADIUS + m.size() * 0.6:
			_caught(t)


func _caught(t: Thief) -> void:
	var egg := egg_by_id(t.carrying_egg)
	var where := t.logic_position()
	if egg:
		_drop_egg(egg, where)
	var landing := WorldLayout.respawn_point(where)
	t.epoch += 1
	_broadcast_effect(t.peer_id, "fall", landing, 0, t.epoch)
	t.prev_logic_position = landing
	var ring := WorldLayout.ring_at(landing)
	var place: String = "your base" if ring == 0 else "the " + str(GameData.biome(ring - 1)["name"])
	_send_to(t.peer_id, "_you_were_caught", [egg.id if egg else -1, place])


func _handle_trap(peer: int, pos: Vector3) -> void:
	var t: Thief = thieves.get(peer)
	var ps: Dictionary = players_state.get(peer, {})
	if t == null or ps.is_empty() or ps["traps_left"] <= 0 or t.fall_left > 0.0 or t.trapped_left > 0.0:
		return
	var from := t.logic_position()
	var offset := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
	if offset.length() > GameData.TRAP_MAX_PLACE_DISTANCE:
		offset = offset.normalized() * GameData.TRAP_MAX_PLACE_DISTANCE
	ps["traps_left"] -= 1
	_create_trap(_next_id, peer, WorldLayout.clamp_to_world(from + offset))
	_next_id += 1


func _create_trap(id: int, owner_peer: int, pos: Vector3) -> Trap:
	var trap := Trap.new()
	var color: Color = GameData.PLAYER_COLORS[Net.player_index(owner_peer) % GameData.PLAYER_COLORS.size()]
	trap.setup(id, owner_peer, pos, color)
	_entities.add_child(trap)
	traps[id] = trap
	_to_ready_peers("_trap_spawned", [id, owner_peer, trap.position])
	return trap


func _remove_trap(id: int) -> void:
	if traps.has(id):
		traps[id].queue_free()
		traps.erase(id)
		_to_ready_peers("_trap_removed", [id])


func _handle_bat(peer: int) -> void:
	var t: Thief = thieves.get(peer)
	var ps: Dictionary = players_state.get(peer, {})
	if t == null or ps.is_empty() or not t.can_act() or server_time < ps["bat_ready_at"]:
		return
	var info: Dictionary = Net.players.get(peer, {})
	var bat_level := int(info.get("bat_level", 0))
	# A small allowance so a client's own cooldown timer never feels out of step.
	ps["bat_ready_at"] = server_time + GameData.bat_cooldown(bat_level, t.pet_element, t.pet_rarity) - 0.1
	_broadcast("_bat_swing", [peer])
	var origin := t.logic_position()
	var reach := GameData.BAT_REACH + t.world_speed() * 0.04
	for m: Monster in monsters.values():
		if m.state == Monster.State.TRAPPED or m.state == Monster.State.EMERGE:
			continue
		if CollisionMath.in_swing(origin, t.forward(), m.position, reach + m.size() * 0.6, GameData.BAT_CONE_DEGREES):
			m.stun(GameData.bat_stun(bat_level, t.pet_element, t.pet_rarity), true)
			var push := (m.position - origin)
			push.y = 0.0
			m.position = WorldLayout.clamp_to_world(m.position + (push.normalized() if push.length() > 0.01 else t.forward()) * 6.0)
			m.prev_position = m.position
	for other_peer in thieves:
		if other_peer == peer:
			continue
		var o: Thief = thieves[other_peer]
		if o.fall_left > 0.0 or not CollisionMath.in_swing(origin, t.forward(), o.logic_position(), reach + 0.5, GameData.BAT_CONE_DEGREES):
			continue
		var egg := carried_egg(other_peer)
		if egg:
			_drop_egg(egg, o.logic_position())
		var push := o.logic_position() - origin
		push.y = 0.0
		o.epoch += 1
		_broadcast_effect(other_peer, "knock", 0, (push.normalized() if push.length() > 0.01 else t.forward()) * 5.0, o.epoch)
		o.prev_logic_position = o.logic_position() + (push.normalized() if push.length() > 0.01 else t.forward()) * 5.0
		_say_to(other_peer, "%s hit you with the bat!" % t.display_name, Color(1.0, 0.4, 0.3))
		if egg:
			_say_to(peer, "You knocked the egg loose. Grab it!", Color(0.6, 1.0, 0.6))


func _place_carried_eggs() -> void:
	for egg in eggs:
		if egg.state == Egg.State.CARRIED and thieves.has(egg.carrier):
			egg.position = thieves[egg.carrier].egg_anchor()


func _update_incubator_pods() -> void:
	var slots: Array = SaveGame.data["incubators"]
	var now := SaveGame.now()
	for i in _incubator_pods.size():
		var pod := _incubator_pods[i]
		var slot: Dictionary = slots[i] if i < slots.size() else {}
		pod.visible = not slot.is_empty()
		if pod.visible:
			var p := Hatchery.progress(slot, now)
			pod.material_override = Meshes.material(GameData.rarity(int(slot["rarity"]))["color"], 0.2 + p * 1.5)
			pod.scale = Vector3.ONE * (0.8 + 0.3 * p)


func _on_peer_disconnected(peer: int) -> void:
	_ready_peers.erase(peer)
	if not thieves.has(peer):
		return
	if multiplayer.is_server():
		var egg := carried_egg(peer)
		if egg:
			_drop_egg(egg, thieves[peer].logic_position())
		players_state.erase(peer)
	thieves[peer].queue_free()
	thieves.erase(peer)


# --- Messages between phones ------------------------------------------------------

func _send_to(peer: int, method: String, args: Array) -> void:
	if peer == Net.my_id():
		callv(method, args)
	elif _ready_peers.has(peer):
		callv("rpc_id", [peer, method] + args)


func _broadcast(method: String, args: Array) -> void:
	callv(method, args)
	for peer in _ready_peers:
		callv("rpc_id", [peer, method] + args)


## Host only: tells every phone that has the world loaded (not this one).
func _to_ready_peers(method: String, args: Array) -> void:
	if not multiplayer.is_server():
		return
	for peer in _ready_peers:
		callv("rpc_id", [peer, method] + args)


func _egg_changed(egg: Egg) -> void:
	_to_ready_peers("_egg_update", [egg.pack()])


func _broadcast_effect(peer: int, kind: String, a: Variant, b: Variant, epoch: int = -1) -> void:
	_broadcast("_thief_effect", [peer, kind, a, b, epoch])


func _say_to(peer: int, text: String, color: Color) -> void:
	_send_to(peer, "_say", [text, color])


## Sent by the host to effect clients only from the host.
func send_effect(peer: int, kind: String, a: Variant, b: Variant) -> void:
	_broadcast_effect(peer, kind, a, b)


@rpc("any_peer", "reliable")
func _client_ready() -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or _ready_peers.has(peer):
		return
	# Bring the newcomer up to date, then include it in every update from now on.
	var all_eggs := []
	for egg in eggs:
		all_eggs.append(egg.pack())
	_eggs_full.rpc_id(peer, all_eggs)
	for m: Monster in monsters.values():
		_monster_spawned.rpc_id(peer, m.id, m.element, m.rarity, m.position)
	for trap: Trap in traps.values():
		_trap_spawned.rpc_id(peer, trap.id, trap.owner_peer, trap.position)
	_ready_peers[peer] = true


@rpc("any_peer", "unreliable_ordered")
func _thief_state(pos: Vector3, vel: Vector3, new_yaw: float, t: float, is_moving: bool, epoch: int) -> void:
	var t_node: Thief = thieves.get(multiplayer.get_remote_sender_id())
	if t_node == null or epoch < t_node.epoch:
		return
	t_node.apply_net_state(WorldLayout.clamp_to_world(Vector3(pos.x, 0.0, pos.z)), vel, new_yaw, clampf(t, 0.0, 1.0), is_moving)


@rpc("any_peer", "reliable")
func _req_trap(pos: Vector3) -> void:
	if multiplayer.is_server():
		_handle_trap(multiplayer.get_remote_sender_id(), pos)


@rpc("any_peer", "reliable")
func _req_bat() -> void:
	if multiplayer.is_server():
		_handle_bat(multiplayer.get_remote_sender_id())


@rpc("authority", "reliable")
func _thief_effect(peer: int, kind: String, a: Variant, b: Variant, epoch: int) -> void:
	var t: Thief = thieves.get(peer)
	if t:
		t.apply_effect(kind, a, b, epoch)


@rpc("authority", "reliable")
func _bat_swing(peer: int) -> void:
	var t: Thief = thieves.get(peer)
	if t:
		t.swing_bat()


@rpc("authority", "reliable")
func _say(text: String, color: Color) -> void:
	say(text, color)


@rpc("authority", "reliable")
func _egg_delivered(rarity_index: int, element_id: String) -> void:
	var result := SaveGame.add_delivered_egg(rarity_index, element_id)
	var rarity_name: String = GameData.rarity(rarity_index)["name"]
	var coins := GameData.delivery_coins(rarity_index)
	match result:
		"incubator":
			say("%s egg is in your incubator! +%d coins" % [rarity_name, coins], Color(0.6, 1.0, 0.6))
		"storage":
			say("Incubators full: %s egg went to storage. +%d coins" % [rarity_name, coins], Color(1.0, 0.85, 0.4))
		_:
			say("No room for the %s egg. Buy more incubators in the shop!" % rarity_name, Color(1.0, 0.4, 0.3))
	lost_egg_id = -1


@rpc("authority", "reliable")
func _you_were_caught(egg_id: int, place: String) -> void:
	lost_egg_id = egg_id
	say("Caught! You fell back to %s. Your egg is where you were caught." % place, Color(1.0, 0.4, 0.3))


@rpc("authority", "reliable")
func _eggs_full(rows: Array) -> void:
	for row in rows:
		_egg_update(row)


@rpc("authority", "reliable")
func _egg_update(row: Array) -> void:
	var egg := egg_by_id(row[0])
	if egg == null:
		return
	if egg.rarity != row[2]:
		egg.set_rarity(row[2])
	egg.state = row[1]
	egg.carrier = row[4]
	if egg.state != Egg.State.CARRIED:
		egg.position = row[3]


@rpc("authority", "reliable")
func _monster_spawned(id: int, element_id: String, rarity_index: int, pos: Vector3) -> void:
	if monsters.has(id):
		return
	var m := Monster.new()
	m.setup(id, element_id, rarity_index)
	m.position = pos
	m.net_position = pos
	_entities.add_child(m)
	monsters[id] = m


@rpc("authority", "reliable")
func _monster_removed(id: int) -> void:
	if monsters.has(id):
		monsters[id].queue_free()
		monsters.erase(id)


@rpc("authority", "reliable")
func _trap_spawned(id: int, owner_peer: int, pos: Vector3) -> void:
	if not traps.has(id):
		_create_trap(id, owner_peer, pos)


@rpc("authority", "reliable")
func _trap_removed(id: int) -> void:
	_remove_trap(id)


## Thieves and traps, 20 times a second.
@rpc("authority", "unreliable_ordered")
func _snapshot(snap: Dictionary) -> void:
	_got_snapshot = true
	server_time = snap["t"]
	var seen := {}
	for row in snap["th"]:
		var peer: int = row[0]
		seen[peer] = true
		var t: Thief = thieves.get(peer)
		if t == null:
			t = _create_thief(peer)
			t.position = row[1]
			t.net_position = row[1]
		t.carrying_egg = row[6]
		if t.is_local:
			_local_traps_left = row[7]
		else:
			t.apply_net_state(row[1], row[2], row[3], row[4], row[5])
	for peer in thieves.keys():
		if not seen.has(peer):
			thieves[peer].queue_free()
			thieves.erase(peer)
	var trap_info: PackedInt32Array = snap["tr"]
	var trap_hold: PackedFloat32Array = snap["trh"]
	for i in trap_hold.size():
		var trap: Trap = traps.get(trap_info[i * 2])
		if trap:
			trap.state = trap_info[i * 2 + 1]
			trap.hold_left = trap_hold[i]


## Monster positions, sent in packet-sized groups alongside each snapshot.
@rpc("authority", "unreliable_ordered")
func _monster_states(info: PackedInt32Array, pos: PackedVector3Array, vel: PackedVector3Array, yaw: PackedFloat32Array) -> void:
	for i in pos.size():
		var m: Monster = monsters.get(info[i * 2])
		if m:
			m.apply_net_state(pos[i], vel[i], yaw[i], info[i * 2 + 1])


func _send_snapshot() -> void:
	var th := []
	for peer in thieves:
		var t: Thief = thieves[peer]
		th.append([peer, t.logic_position(), t.logic_velocity(), t.yaw, t.speed_t, t.moving,
			t.carrying_egg, players_state.get(peer, {}).get("traps_left", 0)])
	var trap_info := PackedInt32Array()
	var trap_hold := PackedFloat32Array()
	for trap: Trap in traps.values():
		trap_info.append_array([trap.id, trap.state])
		trap_hold.append(trap.hold_left)
	var snap := {"t": server_time, "th": th, "tr": trap_info, "trh": trap_hold}
	var all_monsters: Array = monsters.values()
	for peer in _ready_peers:
		_snapshot.rpc_id(peer, snap)
	for start in range(0, all_monsters.size(), MONSTERS_PER_PACKET):
		var info := PackedInt32Array()
		var pos := PackedVector3Array()
		var vel := PackedVector3Array()
		var yaw := PackedFloat32Array()
		for m: Monster in all_monsters.slice(start, start + MONSTERS_PER_PACKET):
			info.append_array([m.id, m.state])
			pos.append(m.position)
			vel.append(m.velocity)
			yaw.append(m.yaw)
		for peer in _ready_peers:
			_monster_states.rpc_id(peer, info, pos, vel, yaw)
