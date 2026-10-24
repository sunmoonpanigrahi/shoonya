extends TestCase


func test_delivery_hatch_and_reload() -> void:
	SaveGame.use_test_profile()
	check_eq(SaveGame.incubator_slots(), 2, "starts with two incubators")
	check_eq(SaveGame.add_delivered_egg(0, "nature"), "incubator")
	check_eq(SaveGame.data["coins"], GameData.delivery_coins(0), "delivery reward")
	# Pretend the egg went in a minute ago.
	SaveGame.data["incubators"][0]["start"] = SaveGame.now() - 61.0
	SaveGame.process_hatchery()
	check_eq(SaveGame.data["pets"].size(), 1, "pet hatched")
	check_eq(SaveGame.equipped_pet()["element"], "nature", "first pet is equipped")
	check_eq(SaveGame.data["coins"], GameData.delivery_coins(0) + 10, "hatch reward")
	check_eq(SaveGame.take_reveals().size(), 1, "one reveal")
	var before := SaveGame.data.duplicate(true)
	SaveGame.load_game()
	check_eq(SaveGame.data["coins"], before["coins"], "coins survive reload")
	check_eq(SaveGame.data["pets"][0]["id"], before["pets"][0]["id"], "pets survive reload")
	check(SaveGame.data["coins"] is int, "coins stay whole numbers")


func test_shop() -> void:
	SaveGame.use_test_profile()
	check(not SaveGame.buy_incubator(), "cannot afford")
	SaveGame.data["coins"] = 1000
	SaveGame.add_delivered_egg(1, "earth")
	SaveGame.add_delivered_egg(1, "earth")
	SaveGame.add_delivered_egg(1, "earth")
	check_eq(SaveGame.data["storage"].size(), 1, "third egg waits in storage")
	check(SaveGame.buy_incubator(), "buy third incubator")
	check_eq(SaveGame.incubator_slots(), 3, "three incubators")
	check_eq(SaveGame.data["storage"].size(), 0, "stored egg moved into the new slot")
	check(SaveGame.buy_bat(), "buy bat level")
	check_eq(SaveGame.player_info()["bat_level"], 1, "bat level shared with the host")
	SaveGame.use_test_profile()
