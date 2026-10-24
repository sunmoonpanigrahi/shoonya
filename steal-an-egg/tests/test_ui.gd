extends TestCase
## Opens every screen so any script error in the UI shows up in the test log.


func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	tree.root.add_child(scene)
	await frames(3)
	return scene


func test_menu_screens_open() -> void:
	SaveGame.use_test_profile()
	SaveGame.data["coins"] = 5000
	SaveGame.add_delivered_egg(3, "ice")
	for path in ["res://scenes/main_menu.tscn", "res://scenes/hatchery.tscn", "res://scenes/pets.tscn", "res://scenes/shop.tscn"]:
		var scene: Node = await _open(path)
		check(scene.is_inside_tree(), path)
		scene.queue_free()
		await frames(1)
	SaveGame.use_test_profile()


func test_join_lobby_opens() -> void:
	Net.mode = "client"
	var lobby: Node = await _open("res://scenes/lobby.tscn")
	check(lobby.is_inside_tree(), "lobby")
	lobby.queue_free()
	Net.stop_discovery()
	Net.setup_solo()
	await frames(1)


func test_pause_menu_and_shop_in_game() -> void:
	SaveGame.use_test_profile()
	SaveGame.data["coins"] = 1000
	Net.setup_solo()
	var world: World = await _open("res://scenes/world.tscn")
	world.hud._open_menu()
	await frames(2)
	check_eq(world.process_mode, Node.PROCESS_MODE_DISABLED, "solo game pauses behind the menu")
	world.hud._open_screen(ShopScreen)
	await frames(3)
	check(world.hud._overlay_screen != null, "shop opened over the game")
	world.hud._overlay_screen.back()
	await frames(2)
	world.hud._close_menu()
	check_eq(world.process_mode, Node.PROCESS_MODE_INHERIT, "game resumes")
	world.queue_free()
	await frames(1)
	SaveGame.use_test_profile()
