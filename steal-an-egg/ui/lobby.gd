extends Control
## Same-Wi-Fi lobby. The host sees its address and who joined; joiners see hosts
## found on the network (or type the host's address) and wait for the host to start.

var _players: VBoxContainer
var _hosts: VBoxContainer
var _status: Label
var _address: LineEdit
var _start: Button


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	column.add_child(bar)
	bar.add_child(UIKit.button("Back", func() -> void: Net.leave(), 140))
	var hosting := Net.mode == "host"
	bar.add_child(UIKit.label("Host a Wi-Fi game" if hosting else "Join a Wi-Fi game", 44, UIKit.ACCENT))
	_status = UIKit.label("", 24, UIKit.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	column.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(UIKit.label("Players", 30))
	_players = VBoxContainer.new()
	left.add_child(_players)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	if hosting:
		var addresses := Net.local_addresses()
		right.add_child(UIKit.label("Your address", 30))
		right.add_child(UIKit.label(", ".join(addresses) if not addresses.is_empty() else "Not connected to Wi-Fi", 34, UIKit.ACCENT))
		var help := UIKit.label("Friends on the same Wi-Fi tap Join Wi-Fi game. If your game doesn't appear for them, they can type this address.", 22, UIKit.MUTED)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(help)
		_start = UIKit.button("Start game", Net.start_game, 320)
		right.add_child(_start)
		_status.text = "Your game is open. Waiting for players to join..."
	else:
		right.add_child(UIKit.label("Games on this Wi-Fi", 30))
		_hosts = VBoxContainer.new()
		right.add_child(_hosts)
		var manual := HBoxContainer.new()
		manual.add_theme_constant_override("separation", 10)
		right.add_child(manual)
		_address = LineEdit.new()
		_address.placeholder_text = "Host address, e.g. 192.168.1.20"
		_address.custom_minimum_size = Vector2(380, 56)
		manual.add_child(_address)
		manual.add_child(UIKit.button("Join", func() -> void: _join(_address.text), 140))
		_status.text = "Looking for games on this Wi-Fi..."
		Net.start_discovery()
		Net.hosts_changed.connect(_refresh_hosts)
		Net.join_failed.connect(_on_join_failed)
		_refresh_hosts()
	Net.players_changed.connect(_refresh_players)
	_refresh_players()


func _on_join_failed(reason: String) -> void:
	_status.text = reason


func _join(address: String) -> void:
	if address.strip_edges().is_empty():
		_status.text = "Type the host's address first."
		return
	var err := Net.join_game(address)
	_status.text = "Connecting to %s..." % address if err == OK else "Could not connect (%s)." % error_string(err)


func _refresh_hosts() -> void:
	if _hosts == null:
		return
	for child in _hosts.get_children():
		child.queue_free()
	if Net.hosts.is_empty():
		_hosts.add_child(UIKit.label("None found yet", 24, UIKit.MUTED))
	for ip in Net.hosts:
		var host: Dictionary = Net.hosts[ip]
		_hosts.add_child(UIKit.button("%s's game (%d players) · %s" % [host["name"], host["players"], ip], _join.bind(ip), 520))


func _refresh_players() -> void:
	for child in _players.get_children():
		child.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = Net.players[id]
		var pet := " with %s" % p["pet_name"] if p.get("pet_name", "") != "" else ""
		var col: Color = GameData.PLAYER_COLORS[int(p["index"]) % GameData.PLAYER_COLORS.size()]
		_players.add_child(UIKit.label("%s%s%s" % [p["name"], pet, "  (host)" if id == 1 else ""], 28, col))
	if Net.mode == "client" and not Net.players.is_empty():
		_status.text = "Connected! Waiting for the host to start..."
	if Net.mode == "host":
		_status.text = "%d player%s in the game. Start when everyone is in." % [Net.players.size(), "" if Net.players.size() == 1 else "s"]
