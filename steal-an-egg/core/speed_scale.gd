class_name SpeedScale
extends RefCounted
## Maps the thief's speed control to the km/h shown on screen and to real movement.
##
## The control runs on a logarithmic scale from 10 km/h to 1 trillion km/h. Real
## movement follows the same curve squeezed into 3–600 m/s: a literal trillion km/h
## would cross the map in a single frame and break floating-point positions.

const MIN_KMH := 10.0
const MAX_KMH := 1.0e12
const MIN_WORLD := 3.0
const MAX_WORLD := 600.0


## Control position (0..1) to displayed km/h.
static func kmh_from_t(t: float) -> float:
	if t <= 0.0:
		return MIN_KMH
	if t >= 1.0:
		return MAX_KMH
	return MIN_KMH * pow(MAX_KMH / MIN_KMH, t)


## Displayed km/h to control position. Not clamped, so monsters can be faster than the thief.
static func t_from_kmh(kmh: float) -> float:
	return log(maxf(kmh, 1e-6) / MIN_KMH) / log(MAX_KMH / MIN_KMH)


static func world_from_t(t: float) -> float:
	return MIN_WORLD * pow(MAX_WORLD / MIN_WORLD, t)


## Displayed km/h to movement speed in metres per second.
static func world_from_kmh(kmh: float) -> float:
	return world_from_t(t_from_kmh(kmh))


static func format_kmh(kmh: float) -> String:
	const UNITS := [[1.0e12, "trillion"], [1.0e9, "billion"], [1.0e6, "million"]]
	for unit in UNITS:
		if kmh >= unit[0] * 0.9995:
			return "%s %s km/h" % [_short_number(kmh / unit[0]), unit[1]]
	return "%s km/h" % _group_thousands(roundi(kmh))


static func _short_number(value: float) -> String:
	if value >= 100.0:
		return str(roundi(value))
	var text := "%.1f" % value
	return text.trim_suffix(".0")


static func _group_thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
