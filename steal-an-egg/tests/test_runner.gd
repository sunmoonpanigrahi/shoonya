extends Node
## Headless test runner. Run from the project folder:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits with code 1 when any check fails or any engine or script error is logged
## while the tests run.

const TEST_SCRIPTS := [
	"res://tests/test_speed_scale.gd",
	"res://tests/test_world_layout.gd",
	"res://tests/test_collision_math.gd",
	"res://tests/test_hatchery.gd",
	"res://tests/test_loot.gd",
	"res://tests/test_pet_index.gd",
	"res://tests/test_save_game.gd",
	"res://tests/test_gameplay.gd",
	"res://tests/test_ui.gd",
]


## Collects errors the engine reports (script errors don't stop a test by themselves).
class ErrorLog extends Logger:
	var current_test := ""
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s: %s:%d %s" % [current_test, file, line, rationale if rationale != "" else code])
		_mutex.unlock()


func _ready() -> void:
	var log := ErrorLog.new()
	OS.add_logger(log)
	# Let the scene tree finish starting up so tests can add scenes to it.
	await get_tree().process_frame
	var failures: Array[String] = []
	var count := 0
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			failures.append("Could not load %s" % path)
			continue
		var suite: TestCase = script.new()
		suite.tree = get_tree()
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			suite.current_test = "%s.%s" % [path.get_file().get_basename(), name]
			log.current_test = suite.current_test
			count += 1
			await suite.call(name)
		failures.append_array(suite.failures)
	OS.remove_logger(log)
	for error in log.errors:
		failures.append("engine error in " + error)
	for failure in failures:
		printerr("FAIL ", failure)
	print("%d tests, %d failures" % [count, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
