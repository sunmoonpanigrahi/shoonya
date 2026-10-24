extends Node
## Plays both sides of a short Wi-Fi game. The host steals an egg; the client must see
## it, see the monsters, place a trap through the host, and move its own thief.

const TIMEOUT := 45.0

var role := "host"
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	get_tree().create_timer(TIMEOUT).timeout.connect(func() -> void: _fail("timed out"))
	SaveGame.use_test_profile("net_" + role)
	SaveGame.data["player_name"] = "Hosty" if role == "host" else "Clienty"
	if role == "host":
		await _run_host()
	else:
		await _run_client()
	if not _failed:
		print("NET SMOKE %s OK" % role.to_upper())
		get_tree().quit(0)


func _run_host() -> void:
	if Net.host_game() != OK:
		_fail("could not host")
		return
	if not await _until(func() -> bool: return Net.players.size() == 2, 20.0):
		_fail("client never joined")
		return
	Net.start_game()
	var world: World = await _world()
	if world == null:
		return
	if not await _until(func() -> bool: return world._ready_peers.size() == 1, 10.0):
		_fail("client never loaded the world")
		return
	# Steal a Forest egg.
	var egg: Egg = world.eggs[0]
	var me := world.local_thief
	me.position = egg.position + Vector3(6, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	me.position = egg.position
	if not await _until(func() -> bool: return egg.state == Egg.State.CARRIED, 2.0):
		_fail("host could not steal the egg")
		return
	var client_id: int = world._ready_peers.keys()[0]
	var client_thief: Thief = world.thieves[client_id]
	var start := client_thief.logic_position()
	if not await _until(func() -> bool: return world.traps.values().any(func(t: Trap) -> bool: return t.owner_peer == client_id), 15.0):
		_fail("client's trap never arrived")
		return
	if not await _until(func() -> bool: return client_thief.logic_position().distance_to(start) > 3.0, 15.0):
		_fail("client's thief never moved on the host")
		return
	# Leaving ends the game for the client, which is its signal to finish.
	Net.leave()
	await get_tree().create_timer(0.5).timeout


func _run_client() -> void:
	Net.mode = "client"
	# Finding hosts by broadcast depends on the network, so it is reported, not required.
	Net.start_discovery()
	var found := await _until(func() -> bool: return not Net.hosts.is_empty(), 4.0)
	print("Discovery found hosts: %s" % (Net.hosts.keys() if found else "none"))
	var joined := false
	for attempt in 30:
		Net.join_game("127.0.0.1")
		if await _until(func() -> bool: return Net.players.size() == 2, 1.0):
			joined = true
			break
	if not joined:
		_fail("could not join the host")
		return
	var world: World = await _world()
	if world == null:
		return
	if not await _until(func() -> bool: return world.thieves.size() == 2 and world.local_thief != null, 10.0):
		_fail("thieves did not appear on the client")
		return
	if not await _until(func() -> bool: return world.carried_egg(1) != null, 15.0):
		_fail("client never saw the host carry an egg")
		return
	if not await _until(func() -> bool: return not world.monsters.is_empty(), 5.0):
		_fail("client never saw the monsters")
		return
	var me := world.local_thief
	world.request_trap(me.position + Vector3(0, 0, -5))
	if not await _until(func() -> bool: return world.traps.values().any(func(t: Trap) -> bool: return t.owner_peer == Net.my_id()), 5.0):
		_fail("client's trap never came back from the host")
		return
	var start := me.position
	me.speed_t = 0.3
	me.move_input = Vector2(0, -1)
	if not await _until(func() -> bool: return me.position.distance_to(start) > 3.0, 3.0):
		_fail("client's thief did not move")
		return
	# Keep running until the host ends the game.
	if not await _until(func() -> bool: return Net.mode == "solo", 15.0):
		_fail("host never ended the game")
		return


func _world() -> World:
	if not await _until(func() -> bool: return get_tree().current_scene is World, 10.0):
		_fail("world scene never loaded")
		return null
	return get_tree().current_scene


func _until(condition: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _fail(reason: String) -> void:
	if _failed:
		return
	_failed = true
	printerr("NET SMOKE %s FAILED: %s" % [role.to_upper(), reason])
	get_tree().quit(1)
