extends TestCase
## Plays through the rules in a real world scene: steal, chase, trap, bat, caught, deliver.


func _make_world() -> World:
	SaveGame.use_test_profile()
	Net.setup_solo()
	Net.world_seed = 777
	var world: World = load("res://scenes/world.tscn").instantiate()
	tree.root.add_child(world)
	await frames(2)
	return world


func _end(world: World) -> void:
	world.queue_free()
	await frames(1)
	Net.setup_solo()
	SaveGame.use_test_profile()


## Moves a thief so that this frame's path runs from `from` to `to`.
func _run(thief: Thief, from: Vector3, to: Vector3) -> void:
	thief.position = from
	thief.net_position = from
	await frames(1)
	thief.position = to
	thief.net_position = to
	await frames(1)


func _wait_for(condition: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await frames(1)
	return condition.call()


func _egg_in_biome(world: World, biome: int) -> Egg:
	for egg in world.eggs:
		if egg.biome == biome and egg.state == Egg.State.NEST:
			return egg
	return null


func test_steal_trap_bat_caught_deliver() -> void:
	var world: World = await _make_world()
	var thief := world.local_thief
	check(thief != null and thief.is_local, "local thief spawned")
	check_eq(WorldLayout.ring_at(thief.position), 0, "starts at the base")
	check_eq(world.traps_left(), 3, "three traps")

	# Steal an egg from a Desert nest.
	var egg := _egg_in_biome(world, 1)
	await _run(thief, egg.position + Vector3(6, 0, 0), egg.position)
	check_eq(egg.state, Egg.State.CARRIED, "egg picked up by running over the nest")
	check_eq(thief.carrying_egg, egg.id, "thief carries it")
	check_eq(world.monsters.size(), int(GameData.rarity(egg.rarity)["guards"]), "guards spawned")
	check(await _wait_for(func() -> bool: return world.monsters.values().all(func(m: Monster) -> bool: return m.state == Monster.State.CHASE), 90), "monsters chase the thief")

	# A trap dropped in a monster's path holds it for 5 seconds.
	var monsters: Array = world.monsters.values()
	var m1: Monster = monsters[0]
	thief.position = m1.position + Vector3(0, 0, 30)
	await frames(1)
	world.request_trap(m1.position + Vector3(0, 0, 3))
	check_eq(world.traps_left(), 2, "one trap used")
	check(await _wait_for(func() -> bool: return m1.state == Monster.State.TRAPPED, 120), "monster ran into the trap")
	check_near(m1.state_left, GameData.TRAP_HOLD_SECONDS, 0.2, "held for 5 s")
	var trap_pos := m1.position
	await frames(60)
	check_eq(m1.position, trap_pos, "trapped monster cannot move")

	# The bat stuns a monster in front of the thief.
	var m2: Monster = monsters[1]
	m2.position = thief.position + thief.forward() * 2.0
	m2.state = Monster.State.CHASE
	world.request_bat()
	check_eq(m2.state, Monster.State.STUNNED, "bat stuns")
	check(m2.position.distance_to(thief.position) > 5.0, "bat knocks the monster back")

	# Caught in the Desert: the egg stays put and the thief falls back into the Forest.
	m2.state = Monster.State.GUARD
	m2.state_left = 0.0
	var caught_at := Vector3(WorldLayout.ring_mid_radius(2), 0, 0)
	thief.position = caught_at
	thief.prev_logic_position = caught_at
	m2.position = caught_at + Vector3(0, 0, 1.0)
	m2.speed = m2.top_speed()
	check(await _wait_for(func() -> bool: return egg.state == Egg.State.DROPPED, 10), "monster caught the thief")
	check(egg.position.distance_to(caught_at) < 3.0, "egg dropped where the thief was caught")
	check(thief.fall_left > 0.0, "thief is falling")
	check_eq(WorldLayout.ring_at(thief.position), 1, "fell into the previous biome (Forest)")
	check_eq(world.lost_egg_id, egg.id, "HUD points back to the lost egg")
	check(await _wait_for(func() -> bool: return thief.fall_left <= 0.0, 120), "landed")

	# Run back for the egg and take it home.
	await _run(thief, egg.position + Vector3(-6, 0, 0), egg.position)
	check_eq(egg.state, Egg.State.CARRIED, "picked the dropped egg up again")
	var rarity := egg.rarity
	await _run(thief, Vector3(0, 0, GameData.BASE_RADIUS + 5.0), Vector3(0, 0, 10))
	check_eq(egg.state, Egg.State.EMPTY, "egg delivered")
	check_eq(world.monsters.size(), 0, "guards gone")
	check_eq(world.traps_left(), 3, "traps refilled at base")
	var slot: Dictionary = SaveGame.data["incubators"][0]
	check_eq(int(slot.get("rarity", -1)), rarity, "egg is in the incubator")
	check_eq(SaveGame.data["coins"], GameData.delivery_coins(rarity), "delivery coins")
	await _end(world)


func test_rival_thief_trap_and_bat() -> void:
	var world: World = await _make_world()
	var me := world.local_thief
	Net.players[2] = {"name": "Rival", "index": 1, "bat_level": 0, "pet_name": "", "pet_element": "", "pet_rarity": 0}
	world._add_player(2)
	var rival: Thief = world.thieves[2]
	check(not rival.is_local, "rival is remote")

	# Rival steals an egg, runs over my trap, is stuck for 5 s and drops the egg.
	var egg := _egg_in_biome(world, 0)
	await _run(rival, egg.position + Vector3(6, 0, 0), egg.position)
	check_eq(egg.carrier, 2, "rival carries the egg")
	me.position = egg.position + Vector3(-20, 0, 0)
	var trap_at := egg.position + Vector3(-10, 0, 0)
	world.request_trap(trap_at)
	await frames(20)
	await _run(rival, egg.position + Vector3(-5, 0, 0), egg.position + Vector3(-15, 0, 0))
	check_near(rival.trapped_left, GameData.TRAP_HOLD_SECONDS, 0.1, "rival trapped for 5 s")
	check_eq(egg.state, Egg.State.DROPPED, "rival dropped the egg")
	check_eq(rival.carrying_egg, -1, "rival no longer carries it")

	# I grab it.
	await _run(me, egg.position + Vector3(0, 0, 6), egg.position)
	check_eq(egg.carrier, 1, "the trapper takes the egg")

	# Rival takes it back after the trap, then my bat knocks it loose.
	world._drop_egg(egg, me.position + Vector3(0, 0, 20))
	rival.trapped_left = 0.0
	await _run(rival, egg.position + Vector3(6, 0, 0), egg.position)
	check_eq(egg.carrier, 2, "rival has it again")
	me.position = rival.net_position - me.forward() * 2.0
	world.players_state[1]["bat_ready_at"] = 0.0
	world.request_bat()
	check_eq(egg.state, Egg.State.DROPPED, "bat knocked the egg loose")
	check(rival.stun_left > 0.0, "rival is dazed")
	check(rival.epoch > 0, "rival's position reports from before the hit are ignored")
	Net.players.erase(2)
	await _end(world)
