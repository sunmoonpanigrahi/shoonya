class_name HatcheryScreen
extends Screen
## Incubators with live countdowns, the storage queue, and new hatchlings.

var _content: VBoxContainer
var _rows: Array[Dictionary] = []
var _storage_label: Label
var _reveal: HatchReveal


func _build() -> void:
	_content = make_page("Hatchery")
	_rebuild()
	SaveGame.changed.connect(_rebuild)
	SaveGame.hatched.connect(_on_hatched)
	_show_reveals()


func _on_hatched(_pet: Dictionary, _coins: int, _slot: int) -> void:
	_show_reveals()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	_rows.clear()
	var slots: Array = SaveGame.data["incubators"]
	_content.add_child(UIKit.label("%d of %d incubators. Eggs keep hatching while the game is closed." % [
		slots.filter(func(s: Dictionary) -> bool: return not s.is_empty()).size(), slots.size()], 22, UIKit.MUTED))
	for slot in slots:
		_content.add_child(_slot_row(slot))
	var storage: Array = SaveGame.data["storage"]
	_storage_label = UIKit.label("", 24)
	_content.add_child(_storage_label)
	if storage.is_empty():
		_storage_label.text = "Storage: empty"
	else:
		var names := PackedStringArray()
		for egg in storage:
			names.append(GameData.rarity(egg["rarity"])["name"])
		_storage_label.text = "Storage (%d/%d), waiting for a free incubator: %s" % [storage.size(), GameData.MAX_STORAGE, ", ".join(names)]
	if OS.is_debug_build():
		var fast := CheckButton.new()
		fast.text = "Test mode: hatch 60x faster (debug builds only)"
		fast.button_pressed = SaveGame.data["fast_hatch"]
		fast.toggled.connect(func(on: bool) -> void:
			SaveGame.data["fast_hatch"] = on
			SaveGame.save_game())
		_content.add_child(fast)


func _slot_row(slot: Dictionary) -> Control:
	var panel := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	if slot.is_empty():
		var icon := EggIcon.make(Color.WHITE)
		icon.empty = true
		row.add_child(icon)
		row.add_child(UIKit.label("Empty incubator. Steal an egg and bring it to your base!", 24, UIKit.MUTED))
		return panel
	var rarity := GameData.rarity(slot["rarity"])
	row.add_child(EggIcon.make(rarity["color"]))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var biome := GameData.biome(GameData.biome_of_element(slot["element"]))
	info.add_child(UIKit.label("%s egg · %s (%s)" % [rarity["name"], biome["name"], GameData.element(slot["element"])["name"]], 26, rarity["color"]))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.max_value = 1.0
	bar.show_percentage = false
	info.add_child(bar)
	var time := UIKit.label("", 30)
	time.custom_minimum_size = Vector2(160, 0)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(time)
	_rows.append({"slot": slot, "bar": bar, "time": time})
	return panel


func _process(delta: float) -> void:
	super._process(delta)
	var now := SaveGame.now()
	for r in _rows:
		r["bar"].value = Hatchery.progress(r["slot"], now)
		r["time"].text = Hatchery.format_time(Hatchery.seconds_left(r["slot"], now))


func _show_reveals() -> void:
	if not is_instance_valid(_reveal):
		_reveal = HatchReveal.show_pending(self)
