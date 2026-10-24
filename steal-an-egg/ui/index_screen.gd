class_name IndexScreen
extends Screen
## The Pet Index: every pet you can hatch, biome by biome. Fill a page for a gift,
## fill everything for the Champion's gift.

var _content: VBoxContainer


func _build() -> void:
	_content = make_page("Pet Index")
	_rebuild()
	SaveGame.changed.connect(_rebuild)


func _rebuild() -> void:
	for child in _content.get_children():
		child.queue_free()
	var found: Dictionary = SaveGame.data["index"]
	var claimed: Array = SaveGame.data["gifts"]
	var total := PetIndex.entries().size()
	var count := PetIndex.found_count(found)

	var summary := card()
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 18)
	summary.add_child(summary_row)
	var summary_info := VBoxContainer.new()
	summary_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_child(summary_info)
	summary_info.add_child(UIKit.label("%d of %d pets found" % [count, total], 30, UIKit.ACCENT))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.max_value = total
	bar.value = count
	bar.show_percentage = false
	summary_info.add_child(bar)
	var champion_text := UIKit.label("Fill every page for the Champion's gift: %s and a golden crown for your thief." % UIKit.coins_text(GameData.INDEX_CHAMPION_COINS), 22, UIKit.MUTED)
	champion_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_info.add_child(champion_text)
	summary_row.add_child(_gift_control(PetIndex.CHAMPION_GIFT, PetIndex.is_complete(found), claimed, "%d to go" % (total - count)))
	_content.add_child(summary)

	for b in GameData.BIOMES.size():
		_content.add_child(_page(b, found, claimed))


func _page(b: int, found: Dictionary, claimed: Array) -> Control:
	var biome := GameData.biome(b)
	var element := GameData.element(biome["element"])
	var panel := card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var title := VBoxContainer.new()
	title.custom_minimum_size = Vector2(230, 0)
	row.add_child(title)
	title.add_child(UIKit.label(biome["name"], 28, element["color"]))
	title.add_child(UIKit.label("%s pets" % element["name"], 20, UIKit.MUTED))
	var tiles := HBoxContainer.new()
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("separation", 14)
	row.add_child(tiles)
	for r in PetIndex.page_rarities(b):
		var have := found.has(PetIndex.key_for(b, r))
		var tile := VBoxContainer.new()
		tile.custom_minimum_size = Vector2(130, 0)
		tile.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := EggIcon.make(element["color"] if have else Color(0.2, 0.17, 0.3), true, 64)
		icon.mystery = not have
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.add_child(icon)
		var name_label := UIKit.label(PetIndex.species_name(b, r) if have else "???", 22, Color.WHITE if have else UIKit.MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(name_label)
		var rarity_label := UIKit.label(GameData.rarity(r)["name"], 18, GameData.rarity(r)["color"])
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(rarity_label)
		tiles.add_child(tile)
	var have_count := PetIndex.page_found_count(found, b)
	var size := PetIndex.page_rarities(b).size()
	row.add_child(_gift_control(PetIndex.page_gift_id(b), PetIndex.is_page_complete(found, b), claimed,
		"%d/%d · gift %s" % [have_count, size, UIKit.coins_text(PetIndex.page_gift_coins(b))]))
	return panel


## A Claim button when the gift is ready, otherwise its progress or "Claimed".
func _gift_control(gift_id: String, complete: bool, claimed: Array, progress: String) -> Control:
	if claimed.has(gift_id):
		return UIKit.label("Gift claimed", 22, UIKit.ACCENT)
	if not complete:
		var l := UIKit.label(progress, 22, UIKit.MUTED)
		l.custom_minimum_size = Vector2(220, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		return l
	return UIKit.button("Claim gift!", func() -> void: _claim(gift_id), 220)


func _claim(gift_id: String) -> void:
	var gift := SaveGame.claim_gift(gift_id)
	if gift.is_empty():
		return
	var popup := PanelContainer.new()
	add_child(popup)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	popup.add_child(box)
	box.add_child(UIKit.label(gift["title"], 40, UIKit.ACCENT))
	box.add_child(UIKit.label("+%s" % UIKit.coins_text(gift["coins"]), 32))
	if gift["crown"]:
		box.add_child(UIKit.label("Your thief now wears the golden crown!", 26, Color(1.0, 0.85, 0.3)))
	box.add_child(UIKit.button("Thanks!", popup.queue_free))
	popup.reset_size()
	popup.position = (size - popup.size) * 0.5
