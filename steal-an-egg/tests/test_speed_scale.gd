extends TestCase


func test_ends_of_the_control_are_exact() -> void:
	check_eq(SpeedScale.kmh_from_t(0.0), 10.0, "slowest")
	check_eq(SpeedScale.kmh_from_t(1.0), 1.0e12, "fastest")
	check_eq(SpeedScale.kmh_from_t(-1.0), 10.0, "below range")
	check_eq(SpeedScale.kmh_from_t(2.0), 1.0e12, "above range")


func test_control_is_logarithmic_and_increasing() -> void:
	var previous := 0.0
	for i in 101:
		var kmh := SpeedScale.kmh_from_t(i / 100.0)
		check(kmh > previous, "km/h must rise at step %d" % i)
		previous = kmh
	check_near(SpeedScale.kmh_from_t(0.5), sqrt(10.0 * 1.0e12), 1.0, "midpoint is the geometric mean")


func test_round_trip() -> void:
	for kmh in [10.0, 40.0, 2000.0, 1.0e7, 3.0e9, 1.0e12]:
		check_near(SpeedScale.kmh_from_t(SpeedScale.t_from_kmh(kmh)) / kmh, 1.0, 1e-6, "round trip %s" % kmh)


func test_world_speed_range() -> void:
	check_near(SpeedScale.world_from_t(0.0), SpeedScale.MIN_WORLD, 1e-6, "min world speed")
	check_near(SpeedScale.world_from_t(1.0), SpeedScale.MAX_WORLD, 1e-3, "max world speed")
	check(SpeedScale.world_from_kmh(3.0e12) > SpeedScale.MAX_WORLD, "divine monsters outrun the fastest thief")
	check(SpeedScale.world_from_kmh(40.0) > SpeedScale.MIN_WORLD, "common monsters beat the slowest thief")


func test_format() -> void:
	check_eq(SpeedScale.format_kmh(10.0), "10 km/h")
	check_eq(SpeedScale.format_kmh(2000.0), "2,000 km/h")
	check_eq(SpeedScale.format_kmh(345678.0), "345,678 km/h")
	check_eq(SpeedScale.format_kmh(1.0e7), "10 million km/h")
	check_eq(SpeedScale.format_kmh(2.5e9), "2.5 billion km/h")
	check_eq(SpeedScale.format_kmh(1.0e12), "1 trillion km/h")
	check_eq(SpeedScale.format_kmh(1.234e12), "1.2 trillion km/h")
