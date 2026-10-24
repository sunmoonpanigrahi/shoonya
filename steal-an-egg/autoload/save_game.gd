extends Node
## The player's saved progress on this device: coins, upgrades, pets and incubators.
## Incubators hatch in real time, also while the app is closed.

signal changed
signal hatched(pet: Dictionary, coins: int)

const DEFAULT_PATH := "user://save.json"

var save_path := DEFAULT_PATH
var data: Dictionary = {}
## Pets hatched since a screen last showed them.
var pending_reveals: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var _tick := 0.0


func _ready() -> void:
	rng.randomize()
	load_game()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		process_hatchery()


static func defaults() -> Dictionary:
	return {
		"version": 1,
		"player_name": "Thief",
		"coins": 0,
		"incubator_level": 0,
		"bat_level": 0,
		"pets": [],
		"equipped_pet": "",
		"incubators": [],
		"storage": [],
		"eggs_delivered": 0,
		"eggs_hatched": 0,
		"fast_hatch": false,
	}


func load_game() -> void:
	data = defaults()
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		if parsed is Dictionary:
			for key in parsed:
				data[key] = parsed[key]
	_normalise()
	process_hatchery()


func save_game() -> void:
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save progress: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DirAccess.rename_absolute(tmp_path, save_path)
	changed.emit()


## Starts a fresh, throwaway profile (used by tests).
func use_test_profile(profile: String = "test") -> void:
	save_path = "user://%s_save.json" % profile
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	data = defaults()
	pending_reveals.clear()
	_normalise()


func now() -> float:
	return Time.get_unix_time_from_system()


func time_scale() -> float:
	return 60.0 if data["fast_hatch"] and OS.is_debug_build() else 1.0


func incubator_slots() -> int:
	return GameData.incubator_slots(int(data["incubator_level"]))


## Stores a delivered egg and pays the delivery reward. Returns "incubator", "storage" or "full".
func add_delivered_egg(rarity_index: int, element_id: String) -> String:
	var result := Hatchery.add_egg(data["incubators"], data["storage"], Hatchery.make_egg(rarity_index, element_id), now(), time_scale())
	if result != "full":
		data["coins"] += GameData.delivery_coins(rarity_index)
		data["eggs_delivered"] += 1
		save_game()
	return result


func process_hatchery() -> void:
	var done := Hatchery.collect_ready(data["incubators"], data["storage"], now(), time_scale())
	if done.is_empty():
		return
	for egg in done:
		var pet := Loot.make_pet(int(egg["rarity"]), egg["element"], rng)
		var coins := int(GameData.rarity(pet["rarity"])["coins"])
		data["pets"].append(pet)
		data["coins"] += coins
		data["eggs_hatched"] += 1
		if data["equipped_pet"] == "":
			data["equipped_pet"] = pet["id"]
		pending_reveals.append({"pet": pet, "coins": coins})
		hatched.emit(pet, coins)
	save_game()


func take_reveals() -> Array[Dictionary]:
	var out := pending_reveals.duplicate()
	pending_reveals.clear()
	return out


func equipped_pet() -> Dictionary:
	for pet in data["pets"]:
		if pet["id"] == data["equipped_pet"]:
			return pet
	return {}


func equip(pet_id: String) -> void:
	data["equipped_pet"] = pet_id
	save_game()


func next_incubator_cost() -> int:
	var level := int(data["incubator_level"])
	return GameData.INCUBATOR_COSTS[level] if level < GameData.INCUBATOR_COSTS.size() else -1


func buy_incubator() -> bool:
	var cost := next_incubator_cost()
	if cost < 0 or data["coins"] < cost:
		return false
	data["coins"] -= cost
	data["incubator_level"] += 1
	Hatchery.resize(data["incubators"], incubator_slots())
	# A new slot can take an egg from storage straight away.
	while not data["storage"].is_empty() and data["incubators"].any(func(s: Dictionary) -> bool: return s.is_empty()):
		Hatchery.add_egg(data["incubators"], [], data["storage"].pop_front(), now(), time_scale())
	save_game()
	return true


func next_bat_cost() -> int:
	var level := int(data["bat_level"])
	return GameData.BAT_COSTS[level] if level < GameData.BAT_COSTS.size() else -1


func buy_bat() -> bool:
	var cost := next_bat_cost()
	if cost < 0 or data["coins"] < cost:
		return false
	data["coins"] -= cost
	data["bat_level"] += 1
	save_game()
	return true


## What other players and the host need to know about this player.
func player_info() -> Dictionary:
	var pet := equipped_pet()
	return {
		"name": str(data["player_name"]).strip_edges().left(16),
		"bat_level": int(data["bat_level"]),
		"pet_name": pet.get("name", ""),
		"pet_element": pet.get("element", ""),
		"pet_rarity": int(pet.get("rarity", 0)),
	}


func _normalise() -> void:
	# JSON brings numbers back as floats.
	for key in ["coins", "incubator_level", "bat_level", "eggs_delivered", "eggs_hatched"]:
		data[key] = int(data[key])
	var incubators: Array = []
	for slot in data["incubators"]:
		if slot is Dictionary and not slot.is_empty():
			slot["rarity"] = int(slot["rarity"])
			incubators.append(slot)
		else:
			incubators.append({})
	data["incubators"] = incubators
	for egg in data["storage"]:
		egg["rarity"] = int(egg["rarity"])
	for pet in data["pets"]:
		pet["rarity"] = int(pet["rarity"])
	Hatchery.resize(data["incubators"], incubator_slots())
