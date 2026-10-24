class_name Hatchery
extends RefCounted
## Real-time incubators. Times are Unix seconds, so eggs keep hatching while the app is closed.
##
## `incubators` holds one entry per slot: an empty Dictionary for a free slot, or
## {"rarity", "element", "start", "duration"}. `storage` holds eggs waiting for a slot.

static func make_egg(rarity_index: int, element_id: String) -> Dictionary:
	return {"rarity": rarity_index, "element": element_id}


## Grows or shrinks the slot list to `slots`, keeping occupied slots.
static func resize(incubators: Array, slots: int) -> void:
	while incubators.size() < slots:
		incubators.append({})
	while incubators.size() > slots and incubators.back().is_empty():
		incubators.pop_back()


## Puts the egg in a free incubator, or in storage if every slot is busy.
## Returns "incubator", "storage", or "full" when there is no room at all.
static func add_egg(incubators: Array, storage: Array, egg: Dictionary, now: float, time_scale: float = 1.0) -> String:
	for i in incubators.size():
		if incubators[i].is_empty():
			incubators[i] = _start(egg, now, time_scale)
			return "incubator"
	if storage.size() < GameData.MAX_STORAGE:
		storage.append(egg.duplicate())
		return "storage"
	return "full"


## Progress 0..1 of an occupied slot.
static func progress(slot: Dictionary, now: float) -> float:
	if slot.is_empty():
		return 0.0
	return clampf((now - float(slot["start"])) / maxf(float(slot["duration"]), 1.0), 0.0, 1.0)


static func seconds_left(slot: Dictionary, now: float) -> float:
	if slot.is_empty():
		return 0.0
	return maxf(float(slot["start"]) + float(slot["duration"]) - now, 0.0)


## Removes every finished egg, moves stored eggs into the freed slots (starting the
## moment the slot freed up), and returns the hatched eggs in the order they finished.
static func collect_ready(incubators: Array, storage: Array, now: float, time_scale: float = 1.0) -> Array[Dictionary]:
	var hatched: Array[Dictionary] = []
	var progressed := true
	while progressed:
		progressed = false
		for i in incubators.size():
			var slot: Dictionary = incubators[i]
			if slot.is_empty():
				continue
			var done_at := float(slot["start"]) + float(slot["duration"])
			if done_at > now:
				continue
			hatched.append({"rarity": slot["rarity"], "element": slot["element"], "hatched_at": done_at})
			incubators[i] = {}
			if not storage.is_empty():
				incubators[i] = _start(storage.pop_front(), done_at, time_scale)
			progressed = true
	hatched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["hatched_at"] < b["hatched_at"])
	return hatched


static func format_time(seconds: float) -> String:
	var s := ceili(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, sec]
	return "%d:%02d" % [m, sec]


static func _start(egg: Dictionary, start: float, time_scale: float) -> Dictionary:
	var rarity_index := int(egg["rarity"])
	var duration := float(GameData.rarity(rarity_index)["hatch_seconds"]) / maxf(time_scale, 1.0)
	return {"rarity": rarity_index, "element": egg["element"], "start": start, "duration": duration}
