extends Node
## Dev tool: renders screenshots of the menus and the game for the README.
## Needs a display (use xvfb-run on Linux):
##   godot --path . --rendering-method gl_compatibility res://tests/screenshots.tscn -- --out=/tmp/shots

var _out := "user://screenshots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	await get_tree().process_frame
	SaveGame.use_test_profile()
	_seed_profile()
	await _shot_scene("res://scenes/main_menu.tscn", "menu", 10)
	await _shot_scene("res://scenes/hatchery.tscn", "hatchery", 10)
	await _shot_scene("res://scenes/pets.tscn", "pets", 10)
	await _shot_scene("res://scenes/shop.tscn", "shop", 10)
	if Net.host_game() == OK:
		await _shot_scene("res://scenes/lobby.tscn", "lobby", 10)
	Net.setup_solo()
	# An Ice egg finishing: the hatchery plays the pet popping out.
	SaveGame.data["incubator_level"] = 2
	Hatchery.resize(SaveGame.data["incubators"], SaveGame.incubator_slots())
	SaveGame.add_delivered_egg(3, "ice")
	SaveGame.data["incubators"][2]["start"] -= 4000.0
	SaveGame.process_hatchery()
	await _shot_scene_after("res://scenes/hatchery.tscn", "hatch", 2.4)
	await _shot_scene("res://scenes/index.tscn", "index", 10)
	await _shot_world()
	SaveGame.use_test_profile()
	get_tree().quit()


func _seed_profile() -> void:
	SaveGame.data["coins"] = 1234
	SaveGame.data["player_name"] = "Robin"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for p in [[5, "dark"], [3, "ice"], [1, "earth"], [0, "nature"], [1, "nature"], [4, "fire"], [7, "light"], [2, "water"]]:
		SaveGame.data["pets"].append(Loot.make_pet(p[0], p[1], rng))
	SaveGame.data["equipped_pet"] = SaveGame.data["pets"][1]["id"]
	# Reloading fills the Pet Index from the pets above, as for an older save.
	SaveGame.save_game()
	SaveGame.load_game()
	SaveGame.add_delivered_egg(2, "water")
	SaveGame.add_delivered_egg(7, "light")
	SaveGame.data["incubators"][0]["start"] -= 1300.0


func _shot_scene(path: String, shot_name: String, frames: int) -> void:
	var scene: Node = load(path).instantiate()
	get_tree().root.add_child(scene)
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(shot_name)
	scene.queue_free()
	await get_tree().process_frame


func _shot_scene_after(path: String, shot_name: String, seconds: float) -> void:
	var scene: Node = load(path).instantiate()
	get_tree().root.add_child(scene)
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	_save(shot_name)
	scene.queue_free()
	await get_tree().process_frame


func _shot_world() -> void:
	Net.setup_solo()
	Net.world_seed = 4242
	var world: World = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().physics_frame
	var thief := world.local_thief
	# Stand in the Forest next to a nest, egg in hand, with its monsters waking up.
	var egg := world.eggs[0]
	thief.position = egg.position + Vector3(3, 0, 3)
	thief.prev_logic_position = egg.position
	for i in 3:
		await get_tree().physics_frame
	thief.position = egg.position + Vector3(-14, 0, -6)
	thief.prev_logic_position = thief.position
	thief.speed_t = 0.0
	for i in 50:
		await get_tree().physics_frame
	# Drop a trap in front of the first monster, then look back at the chase from the side.
	var m: Monster = world.monsters.values()[0]
	world.request_trap(m.position + (thief.position - m.position).normalized() * 1.5)
	for i in 20:
		await get_tree().physics_frame
	var away := thief.position - egg.position
	thief.yaw = atan2(-away.x, -away.z)
	world.camera.cam_yaw = thief.yaw + 2.3
	for i in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save("chase")
	# Fast run through the Volcano.
	thief.position = Vector3(0, 0, -3000)
	thief.prev_logic_position = thief.position
	thief.speed_t = 0.9
	thief.move_input = Vector2(0, -1)
	for i in 40:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	_save("volcano")
	# Home base: an egg cracks open in its incubator and the pet joins the others.
	thief.move_input = Vector2.ZERO
	thief.speed_t = 0.1
	thief.position = WorldLayout.pad_position(0) + Vector3(0, 0, 12)
	thief.yaw = 0.0
	world.camera.cam_yaw = 0.0
	for i in 30:
		await get_tree().physics_frame
	SaveGame.data["incubators"][0] = {}
	SaveGame.add_delivered_egg(6, "light")
	SaveGame.data["incubators"][0]["start"] -= 99999.0
	SaveGame.process_hatchery()
	SaveGame.take_reveals()
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	_save("hatching")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_save("base")
	world.queue_free()


func _save(shot_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(shot_name + ".png"))
	print("saved ", shot_name)
