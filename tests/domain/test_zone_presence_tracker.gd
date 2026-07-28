class_name TestZonePresenceTracker
extends RefCounted

## Domain tests for zone presence and the event bus (active_zones.md §14):
## that crossing a region border publishes area_entered then area_exited, that
## staying inside publishes nothing, that overlays are ignored, and that the bus
## dispatches only the kinds it was configured for.

const BOARD_CELLS := 16


static func run_all() -> void:
	_test_enter_then_exit_a_region()
	_test_staying_inside_publishes_nothing()
	_test_overlay_is_not_a_presence_source()
	_test_clear_citizen_publishes_exits()
	_test_bus_skips_unconfigured_kinds()
	print("    [PASS] Zone Presence Tracker Tests")


## A capture bus that records every dispatched event in order, so a test can
## assert on the exact enter/exit sequence.
static func _recording_bus() -> ZoneEventBus:
	var bus := ZoneEventBus.new()
	var seen: Array = []
	bus.configure({
		"area_entered": func(event: ZoneEvent): seen.append("enter:%s:%d" % [event.subject_id, event.ai_id]),
		"area_exited": func(event: ZoneEvent): seen.append("exit:%s:%d" % [event.subject_id, event.ai_id]),
	})
	bus.set_meta("seen", seen)
	return bus


## A layer with one region covering cells (2..4, 2..4).
static func _layer() -> MapZoneLayer:
	var zones := MapZoneLayer.new()
	var region := ZoneAreaRecord.new()
	region.id = &"yard"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.add_rect(Rect2i(2, 2, 3, 3)) # covers (2,2)..(4,4)
	zones.areas.append(region)
	return zones


## Walking into the yard publishes area_entered; walking out publishes exited.
static func _test_enter_then_exit_a_region() -> void:
	var index := ZonePresenceIndex.new()
	index.rebuild(_layer(), BOARD_CELLS)
	var bus := _recording_bus()
	var tracker := ZonePresenceTracker.new()
	tracker.configure(index, bus)
	# Start outside, step into (3,3), then back out to (0,0).
	tracker.on_citizen_cell_changed(7, Vector2i(0, 0))
	tracker.on_citizen_cell_changed(7, Vector2i(3, 3))
	tracker.on_citizen_cell_changed(7, Vector2i(0, 0))
	var seen: Array = bus.get_meta("seen")
	assert(seen == ["enter:yard:7", "exit:yard:7"], "enter then exit: %s" % str(seen))


## Moving between two cells inside the same region publishes nothing.
static func _test_staying_inside_publishes_nothing() -> void:
	var index := ZonePresenceIndex.new()
	index.rebuild(_layer(), BOARD_CELLS)
	var bus := _recording_bus()
	var tracker := ZonePresenceTracker.new()
	tracker.configure(index, bus)
	tracker.on_citizen_cell_changed(9, Vector2i(2, 2))
	tracker.on_citizen_cell_changed(9, Vector2i(4, 4))
	var seen: Array = bus.get_meta("seen")
	assert(seen == ["enter:yard:9"], "only the first enter, no re-enter on internal move: %s" % str(seen))


## An overlay over the same cell is not a presence source — §14 publishes only
## for addressable room/region, never for a technical overlay.
static func _test_overlay_is_not_a_presence_source() -> void:
	var zones := MapZoneLayer.new()
	var region := ZoneAreaRecord.new()
	region.id = &"yard"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.add_rect(Rect2i(2, 2, 3, 3))
	zones.areas.append(region)
	var overlay := ZoneAreaRecord.new()
	overlay.id = &"smoke"
	overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	overlay.add_rect(Rect2i(2, 2, 3, 3))
	zones.areas.append(overlay)

	var index := ZonePresenceIndex.new()
	index.rebuild(zones, BOARD_CELLS)
	var bus := _recording_bus()
	var tracker := ZonePresenceTracker.new()
	tracker.configure(index, bus)
	tracker.on_citizen_cell_changed(1, Vector2i(3, 3))
	var seen: Array = bus.get_meta("seen")
	assert(seen == ["enter:yard:1"], "overlay 'smoke' never publishes: %s" % str(seen))


## clear_citizen publishes an exit for every area still held, so a departed
## resident does not linger "inside" a region.
static func _test_clear_citizen_publishes_exits() -> void:
	var index := ZonePresenceIndex.new()
	index.rebuild(_layer(), BOARD_CELLS)
	var bus := _recording_bus()
	var tracker := ZonePresenceTracker.new()
	tracker.configure(index, bus)
	tracker.on_citizen_cell_changed(5, Vector2i(3, 3))
	tracker.clear_citizen(5)
	var seen: Array = bus.get_meta("seen")
	assert(seen == ["enter:yard:5", "exit:yard:5"], "clear publishes pending exits: %s" % str(seen))


## A bus with no handlers configured is inert — dispatch is a no-op, which is
## exactly the state at session start before a rules layer subscribes.
static func _test_bus_skips_unconfigured_kinds() -> void:
	var bus := ZoneEventBus.new()
	bus.configure({})
	# Must not crash and must do nothing.
	bus.dispatch(ZoneEvent.area_entered(&"yard", 1))
	bus.dispatch(ZoneEvent.area_exited(&"yard", 1))
	print("        (unconfigured bus dispatch is a no-op)")
