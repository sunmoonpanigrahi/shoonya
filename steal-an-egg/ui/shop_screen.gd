class_name ShopScreen
extends Screen
## Spend coins on more incubators and a stronger bat.

var _content: VBoxContainer


func _build() -> void:
	_content = make_page("Shop")
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var slots := SaveGame.incubator_slots()
	_content.add_child(_item("Incubator",
		"%d of %d incubators. More incubators hatch more eggs at once." % [slots, GameData.MAX_INCUBATORS],
		SaveGame.next_incubator_cost(), SaveGame.buy_incubator))
	var level := int(SaveGame.data["bat_level"])
	var info := SaveGame.player_info()
	_content.add_child(_item("Baseball bat level %d" % (level + 1),
		"Stuns monsters for %.2f s, recharges in %.2f s. Each level stuns longer and swings sooner." % [
			GameData.bat_stun(level, info["pet_element"], info["pet_rarity"]),
			GameData.bat_cooldown(level, info["pet_element"], info["pet_rarity"])],
		SaveGame.next_bat_cost(), SaveGame.buy_bat))
	if not Net.is_online() or not Net.in_game:
		return
	_content.add_child(UIKit.label("Bat upgrades bought during a Wi-Fi game count from the next game.", 20, UIKit.MUTED))


func _item(title: String, text: String, cost: int, buy: Callable) -> Control:
	var panel := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UIKit.label(title, 30, UIKit.ACCENT))
	var body := UIKit.label(text, 22, UIKit.MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(body)
	if cost < 0:
		row.add_child(UIKit.label("Maxed out", 26))
		return panel
	var b := UIKit.button("Buy · %s" % UIKit.coins_text(cost), func() -> void:
		if buy.call():
			_rebuild(), 300)
	b.disabled = SaveGame.data["coins"] < cost
	row.add_child(b)
	return panel
