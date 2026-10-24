class_name PetsScreen
extends Screen
## Every pet you have hatched. The equipped pet follows you and gives its perk.

var _content: VBoxContainer


func _build() -> void:
	_content = make_page("Pets")
	_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var pets: Array = SaveGame.data["pets"].duplicate()
	if pets.is_empty():
		_content.add_child(UIKit.label("No pets yet. Hatch an egg at your base to get one!", 26, UIKit.MUTED))
		return
	pets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rarity"] > b["rarity"])
	_content.add_child(UIKit.label("%d pets. Equip one to bring it along." % pets.size(), 22, UIKit.MUTED))
	for pet in pets:
		var panel := card()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		panel.add_child(row)
		row.add_child(EggIcon.make(GameData.element(pet["element"])["color"], true))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var rarity := GameData.rarity(pet["rarity"])
		info.add_child(UIKit.label("%s · %s %s" % [pet["name"], rarity["name"], GameData.element(pet["element"])["name"]], 28, rarity["color"]))
		var perk := UIKit.label(Loot.perk_description(pet), 22, UIKit.MUTED)
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(perk)
		if pet["id"] == SaveGame.data["equipped_pet"]:
			row.add_child(UIKit.label("Equipped", 26, UIKit.ACCENT))
		else:
			var id: String = pet["id"]
			row.add_child(UIKit.button("Equip", func() -> void:
				SaveGame.equip(id)
				_rebuild(), 180))
		_content.add_child(panel)
