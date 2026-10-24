extends Node
## Two-phone smoke test over the network, run as two processes on one machine:
##   godot --headless --path . res://tests/net_smoke.tscn -- --role=host
##   godot --headless --path . res://tests/net_smoke.tscn -- --role=client
## See tests/run_net_smoke.sh.


func _ready() -> void:
	# The driver lives outside the current scene so it survives the switch to the world.
	var driver: Node = load("res://tests/net_smoke_driver.gd").new()
	get_tree().root.add_child.call_deferred(driver)
