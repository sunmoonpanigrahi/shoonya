extends Node
## Loads every script in the project and fails if any has an error. Run from the project folder:
##   godot --headless --path . res://tests/check_scripts.tscn


func _ready() -> void:
	var bad: Array[String] = []
	var paths: Array[String] = []
	_collect("res://", paths)
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			bad.append(path)
	for path in bad:
		printerr("BROKEN ", path)
	print("%d scripts checked, %d broken" % [paths.size(), bad.size()])
	get_tree().quit(1 if not bad.is_empty() else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
