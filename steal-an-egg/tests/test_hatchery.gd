extends TestCase


func test_hatch_times_match_the_design() -> void:
	var expected := {"common": 60, "rare": 600, "epic": 1800, "legendary": 2700,
		"mythical": 3300, "secret": 3600, "eternal": 7200, "divine": 86400}
	for r in GameData.RARITIES:
		check_eq(r["hatch_seconds"], expected[r["id"]], r["id"])


func test_egg_hatches_after_its_time() -> void:
	var incubators: Array = []
	var storage: Array = []
	Hatchery.resize(incubators, 2)
	check_eq(Hatchery.add_egg(incubators, storage, Hatchery.make_egg(0, "nature"), 1000.0), "incubator")
	check_near(Hatchery.progress(incubators[0], 1030.0), 0.5, 1e-6, "half way")
	check_eq(Hatchery.collect_ready(incubators, storage, 1059.0).size(), 0, "not yet")
	var hatched := Hatchery.collect_ready(incubators, storage, 1060.0)
	check_eq(hatched.size(), 1, "hatched at 1:00")
	check(incubators[0].is_empty(), "slot freed")


func test_storage_moves_in_while_app_was_closed() -> void:
	var incubators: Array = []
	var storage: Array = []
	Hatchery.resize(incubators, 1)
	Hatchery.add_egg(incubators, storage, Hatchery.make_egg(0, "nature"), 0.0)
	check_eq(Hatchery.add_egg(incubators, storage, Hatchery.make_egg(0, "earth"), 0.0), "storage")
	check_eq(Hatchery.add_egg(incubators, storage, Hatchery.make_egg(1, "water"), 0.0), "storage")
	# Reopen after 10 minutes: two commons are done, the rare started at 2:00 and has 2:00 left.
	var hatched := Hatchery.collect_ready(incubators, storage, 600.0)
	check_eq(hatched.size(), 2, "both commons hatched")
	check_eq(hatched[1]["element"], "earth", "in finishing order")
	check_eq(incubators[0]["rarity"], 1, "rare egg moved in")
	check_near(Hatchery.seconds_left(incubators[0], 600.0), 120.0, 1e-6, "rare started when the slot freed")


func test_divine_takes_a_day() -> void:
	var incubators: Array = [{}]
	var storage: Array = []
	Hatchery.add_egg(incubators, storage, Hatchery.make_egg(7, "light"), 0.0)
	check_eq(Hatchery.collect_ready(incubators, storage, 86399.0).size(), 0, "not before a day")
	check_eq(Hatchery.collect_ready(incubators, storage, 86400.0).size(), 1, "after a day")


func test_full_hatchery() -> void:
	var incubators: Array = [{}]
	var storage: Array = []
	Hatchery.add_egg(incubators, storage, Hatchery.make_egg(0, "nature"), 0.0)
	for i in GameData.MAX_STORAGE:
		Hatchery.add_egg(incubators, storage, Hatchery.make_egg(0, "nature"), 0.0)
	check_eq(Hatchery.add_egg(incubators, storage, Hatchery.make_egg(0, "nature"), 0.0), "full")


func test_format_time() -> void:
	check_eq(Hatchery.format_time(59.2), "1:00")
	check_eq(Hatchery.format_time(600.0), "10:00")
	check_eq(Hatchery.format_time(86400.0), "24:00:00")
