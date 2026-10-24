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
	for path in ["res://scenes/main_menu.tscn", "res://scenes/hatchery.tscn", "res://scenes/pets.tscn", "res://scenes/shop.tscn", "res://scenes/index.tscn"]:
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


func test_hatch_reveal_shows_each_new_pet() -> void:
	SaveGame.use_test_profile()
	SaveGame.add_delivered_egg(0, "nature")
	SaveGame.add_delivered_egg(4, "fire")
	for slot in SaveGame.data["incubators"]:
		slot["start"] = SaveGame.now() - 4000.0
	SaveGame.process_hatchery()
	check_eq(SaveGame.pending_reveals.size(), 2, "two pets waiting to come out")
	var menu: Node = await _open("res://scenes/main_menu.tscn")
	var reveal: HatchReveal = menu.get_children().filter(func(n: Node) -> bool: return n is HatchReveal).front()
	check(reveal != null, "main menu plays the hatch")
	check(SaveGame.pending_reveals.is_empty(), "reveals taken")
	check(reveal._current["new_entry"], "first pet of its kind is new in the index")
	reveal._on_equip()
	check_eq(SaveGame.data["equipped_pet"], reveal._current["pet"]["id"], "equip from the reveal")
	reveal._advance()
	reveal._advance()
	await frames(2)
	check(not is_instance_valid(reveal), "closes after the last pet")
	menu.queue_free()
	await frames(1)
	SaveGame.use_test_profile()


func test_index_gift_can_be_claimed() -> void:
	SaveGame.use_test_profile()
	SaveGame.data["index"] = {"forest:0": true, "forest:1": true}
	var screen: IndexScreen = await _open("res://scenes/index.tscn")
	var coins: int = SaveGame.data["coins"]
	screen._claim("page_forest")
	await frames(2)
	check_eq(SaveGame.data["coins"], coins + PetIndex.page_gift_coins(0), "gift paid from the index screen")
	screen.queue_free()
	await frames(1)
	SaveGame.use_test_profile()

