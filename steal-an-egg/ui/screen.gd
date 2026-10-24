class_name Screen
extends Control
## Base for full-screen menus. Opened from the main menu, Back returns there; opened
## from the in-game menu (`embedded`), Back just closes the screen.

signal closed

const MENU_SCENE := "res://scenes/main_menu.tscn"

var embedded := false
var _coins_label: Label


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.background(self)
	_build()


func _build() -> void:
	pass


func back() -> void:
	if embedded:
		closed.emit()
		queue_free()
	else:
		get_tree().change_scene_to_file(MENU_SCENE)


## Title bar with a Back button and the coin count; returns the scrolling content box.
func make_page(title: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	column.add_child(bar)
	bar.add_child(UIKit.button("Back", back, 140))
	var heading := UIKit.label(title, 44, UIKit.ACCENT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(heading)
	_coins_label = UIKit.label("", 28, UIKit.ACCENT)
	bar.add_child(_coins_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content


func _process(_delta: float) -> void:
	if _coins_label:
		_coins_label.text = UIKit.coins_text(SaveGame.data["coins"])


func card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel
