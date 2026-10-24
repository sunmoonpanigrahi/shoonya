class_name TestCase
extends RefCounted
## Base for tests: every method starting with `test_` is run by tests/test_runner.gd.

var failures: Array[String] = []
var current_test := ""
## Set by the runner so async tests can wait for frames.
var tree: SceneTree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: %s expected %s, got %s" % [current_test, message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s expected %s ± %s, got %s" % [current_test, message, expected, tolerance, actual])


func frames(count: int) -> void:
	for i in count:
		await tree.physics_frame
