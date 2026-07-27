class_name ZoneRouteRecord
extends RefCounted

## A line in the shared active-zone model: an ordered reference list over
## already-authored points. It adds no geometry of its own (§3, §16).

const CYCLE_ONCE := &"once"
const CYCLE_LOOP := &"loop"
const CYCLE_PINGPONG := &"pingpong"
const CYCLES: Array[StringName] = [CYCLE_ONCE, CYCLE_LOOP, CYCLE_PINGPONG]

var id: StringName = &"route_1"
var stops: Array[StringName] = []
var cycle: StringName = CYCLE_ONCE
var wait_minutes: float = 0.0
var profile: StringName = &""


func to_dict() -> Dictionary:
	var data := {
		"id": String(id),
		"stops": stops.map(func(stop: StringName) -> String: return String(stop)),
	}
	if cycle != CYCLE_ONCE:
		data["cycle"] = String(cycle)
	if not is_zero_approx(wait_minutes):
		data["wait_minutes"] = wait_minutes
	if profile != &"":
		data["profile"] = String(profile)
	return data


static func from_dict(data: Dictionary) -> ZoneRouteRecord:
	var route := ZoneRouteRecord.new()
	route.id = StringName(data.get("id", "route_1"))
	for raw_stop in data.get("stops", []):
		var stop := StringName(raw_stop)
		if stop != &"":
			route.stops.append(stop)
	route.cycle = StringName(data.get("cycle", CYCLE_ONCE))
	route.wait_minutes = maxf(0.0, float(data.get("wait_minutes", 0.0)))
	route.profile = StringName(data.get("profile", ""))
	return route


static func cycle_display_name(value: StringName) -> String:
	match value:
		CYCLE_ONCE: return "Один раз"
		CYCLE_LOOP: return "По кругу"
		CYCLE_PINGPONG: return "Туда-обратно"
		_: return String(value)
