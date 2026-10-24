extends Control
## Title screen: play solo, host or join a same-Wi-Fi game, and visit the hatchery, pets and shop.

const LOBBY_SCENE := "res://scenes/lobby.tscn"

var _message: Label
var _coins: Label
var _hatching: Label
var _index_button: Button


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.background(self)
	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_art.bind(art))
	add_child(art)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UIKit.label("STEAL AN EGG", 76, UIKit.ACCENT))
	var tagline := UIKit.label("Grab monster eggs, outrun the monsters at up to 1 trillion km/h, and hatch them at your base.", 24, UIKit.MUTED)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(520, 0)
	left.add_child(tagline)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	left.add_child(name_row)
	name_row.add_child(UIKit.label("Your name", 24))
	var name_edit := LineEdit.new()
	name_edit.text = SaveGame.data["player_name"]
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(280, 56)
	name_edit.text_changed.connect(func(text: String) -> void: SaveGame.data["player_name"] = text)
	name_edit.text_submitted.connect(func(_text: String) -> void: SaveGame.save_game())
	name_edit.focus_exited.connect(SaveGame.save_game)
	name_row.add_child(name_edit)
	_coins = UIKit.label("", 28, UIKit.ACCENT)
	left.add_child(_coins)
	_hatching = UIKit.label("", 22, UIKit.MUTED)
	left.add_child(_hatching)
	_message = UIKit.label(Net.last_message, 22, Color(1.0, 0.6, 0.5))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(520, 0)
	left.add_child(_message)
	Net.last_message = ""

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 14)
	columns.add_child(right)
	right.add_child(UIKit.button("Play solo", _play_solo, 380))
	right.add_child(UIKit.button("Host Wi-Fi game", _host, 380))
	right.add_child(UIKit.button("Join Wi-Fi game", _join, 380))
	right.add_child(UIKit.button("Hatchery", _go.bind("res://scenes/hatchery.tscn"), 380))
	right.add_child(UIKit.button("Pets", _go.bind("res://scenes/pets.tscn"), 380))
	_index_button = UIKit.button("Pet Index", _go.bind("res://scenes/index.tscn"), 380)
	right.add_child(_index_button)
	right.add_child(UIKit.button("Shop", _go.bind("res://scenes/shop.tscn"), 380))
	# Eggs that hatched while you were away come out now.
	HatchReveal.show_pending(self)


func _process(_delta: float) -> void:
	_coins.text = UIKit.coins_text(SaveGame.data["coins"])
	var gifts := SaveGame.claimable_gifts().size()
	_index_button.text = "Pet Index  ·  %d gift%s!" % [gifts, "" if gifts == 1 else "s"] if gifts > 0 else "Pet Index"
	var busy := 0
	var soonest := INF
	for slot in SaveGame.data["incubators"]:
		if not slot.is_empty():
			busy += 1
			soonest = minf(soonest, Hatchery.seconds_left(slot, SaveGame.now()))
	_hatching.text = "No eggs hatching" if busy == 0 else "%d eggs hatching · next in %s" % [busy, Hatchery.format_time(soonest)]


func _play_solo() -> void:
	SaveGame.save_game()
	Net.start_solo()


func _host() -> void:
	SaveGame.save_game()
	var err := Net.host_game()
	if err != OK:
		_message.text = "Could not open a game on this Wi-Fi (%s)." % error_string(err)
		return
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _join() -> void:
	SaveGame.save_game()
	Net.mode = "client"
	Net.rejoin_address = ""
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _go(scene: String) -> void:
	SaveGame.save_game()
	get_tree().change_scene_to_file(scene)


func _draw_art(art: Control) -> void:
	var s := art.size
	var colors := [GameData.rarity(0)["color"], GameData.rarity(2)["color"], GameData.rarity(7)["color"], GameData.rarity(5)["color"]]
	var spots := [Vector2(0.08, 0.86), Vector2(0.2, 0.9), Vector2(0.33, 0.84), Vector2(0.46, 0.9)]
	for i in spots.size():
		UIKit.draw_egg(art, spots[i] * s, 90.0 + 16.0 * i, colors[i])
