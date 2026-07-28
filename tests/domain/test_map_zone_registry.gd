class_name TestMapZoneRegistry
extends RefCounted

## Domain tests for the map-zone session registry (active_zones.md §13): that a
## layer's areas become addressable state, that owner and flags mutate and
## short-circuit on no-ops, that the relational `owner` audience resolves, and
## that the session slice has the shape a future save will need.


static func run_all() -> void:
	_test_build_from_creates_state_per_area()
	_test_set_owner_mutates_and_short_circuits()
	_test_set_flag_round_trips()
	_test_is_owned_by_matches_current_owner()
	_test_unknown_zone_is_inert()
	_test_session_state_shape()
	_test_session_state_round_trips_through_save()
	_test_stale_zone_state_is_dropped_on_restore()
	print("    [PASS] Map Zone Registry Tests")


## A layer with two areas yields two addressable zones; build_from is idempotent.
static func _test_build_from_creates_state_per_area() -> void:
	var registry := MapZoneRegistry.new()
	registry.build_from(_layer_with_two_areas())
	assert(registry.state(&"gate_yard") != null)
	assert(registry.state(&"forest") != null)
	# Rebuild replaces, not appends.
	registry.build_from(_layer_with_two_areas())
	assert(registry.session_state_to_dict().size() == 2)


## set_owner changes the owner and returns true; setting the same owner again is
## a no-op returning false — the signal a future `owner_changed` event will skip.
static func _test_set_owner_mutates_and_short_circuits() -> void:
	var registry := MapZoneRegistry.new()
	registry.build_from(_layer_with_two_areas())
	assert(registry.owner_of(&"gate_yard") == &"")
	assert(registry.set_owner(&"gate_yard", &"faction:red"))
	assert(registry.owner_of(&"gate_yard") == &"faction:red")
	assert(not registry.set_owner(&"gate_yard", &"faction:red"), "same owner is a no-op")


## Flags round-trip, and re-setting the same value is a no-op.
static func _test_set_flag_round_trips() -> void:
	var registry := MapZoneRegistry.new()
	registry.build_from(_layer_with_two_areas())
	assert(registry.set_flag(&"gate_yard", &"cleared", true))
	assert(registry.flag_of(&"gate_yard", &"cleared") == true)
	assert(registry.flag_of(&"gate_yard", &"waves_left", 0) == 0)
	assert(registry.set_flag(&"gate_yard", &"waves_left", 3))
	assert(registry.flag_of(&"gate_yard", &"waves_left") == 3)
	assert(not registry.set_flag(&"gate_yard", &"waves_left", 3), "same flag value is a no-op")


## is_owned_by matches the zone's current owner tag, not a fixed one — the
## relational `owner` audience (§12) that lets one markup serve a capture point.
static func _test_is_owned_by_matches_current_owner() -> void:
	var registry := MapZoneRegistry.new()
	registry.build_from(_layer_with_two_areas())
	assert(not registry.is_owned_by(&"gate_yard", [&"faction:red"]), "unowned zone matches nobody")
	registry.set_owner(&"gate_yard", &"faction:red")
	assert(registry.is_owned_by(&"gate_yard", [&"faction:red", &"staff"]))
	assert(not registry.is_owned_by(&"gate_yard", [&"faction:blue"]))


## A zone id that does not exist reads as inert — no owner, no flag, no crash.
static func _test_unknown_zone_is_inert() -> void:
	var registry := MapZoneRegistry.new()
	assert(registry.state(&"no_such") == null)
	assert(registry.owner_of(&"no_such") == &"")
	assert(registry.flag_of(&"no_such", &"k", "default") == "default")
	assert(not registry.set_owner(&"no_such", &"faction:red"))
	assert(not registry.is_owned_by(&"no_such", [&"faction:red"]))


## The session slice is exactly `{id, owner, flags}` per zone, in id order —
## geometry never leaves the file, and stable order keeps a double save identical.
static func _test_session_state_shape() -> void:
	var registry := MapZoneRegistry.new()
	registry.build_from(_layer_with_two_areas())
	registry.set_owner(&"forest", &"player")
	registry.set_flag(&"gate_yard", &"cleared", true)
	var snapshot := registry.session_state_to_dict()
	assert(snapshot.size() == 2)
	# Sorted by id: "forest" before "gate_yard".
	assert(snapshot[0]["id"] == "forest")
	assert(snapshot[0]["owner"] == "player")
	assert(snapshot[0]["flags"] == {})
	assert(snapshot[1]["id"] == "gate_yard")
	assert(snapshot[1]["owner"] == "")
	assert(snapshot[1]["flags"] == {"cleared": true})


static func _layer_with_two_areas() -> MapZoneLayer:
	var zones := MapZoneLayer.new()
	var region := ZoneAreaRecord.new()
	region.id = &"gate_yard"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.add_rect(Rect2i(2, 3, 4, 2))
	zones.areas.append(region)
	var overlay := ZoneAreaRecord.new()
	overlay.id = &"forest"
	overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	overlay.effects = {ZoneEffects.KEY_COST: 2.0}
	overlay.add_rect(Rect2i(8, 8, 3, 3))
	zones.areas.append(overlay)
	return zones


## A save round-trip: export the session state, rebuild a fresh registry from
## the same definition, lay the snapshot back over it, and the owner/flags come
## back identical. This is the contract a player's captured regions rely on.
static func _test_session_state_round_trips_through_save() -> void:
	var before := MapZoneRegistry.new()
	before.build_from(_layer_with_two_areas())
	before.set_owner(&"forest", &"player")
	before.set_flag(&"gate_yard", &"cleared", true)
	before.set_flag(&"gate_yard", &"waves_left", 3)
	var snapshot := before.session_state_to_dict()

	# The loader rebuilds definitions from the map document, then applies the save.
	var after := MapZoneRegistry.new()
	after.build_from(_layer_with_two_areas())
	after.apply_session_state(snapshot)
	assert(after.owner_of(&"forest") == &"player")
	assert(after.flag_of(&"gate_yard", &"cleared") == true)
	assert(after.flag_of(&"gate_yard", &"waves_left") == 3)
	# A snapshot re-exported is byte-identical — a save made twice with no edit
	# produces the same bytes.
	assert(after.session_state_to_dict() == snapshot)


## State for a zone the author removed between save and load is dropped, not
## resurrected: a re-authored map owns its geometry, and a dangling state record
## must not bring back a deleted region (§13).
static func _test_stale_zone_state_is_dropped_on_restore() -> void:
	var before := MapZoneRegistry.new()
	before.build_from(_layer_with_two_areas())
	before.set_owner(&"gate_yard", &"faction:red")
	var snapshot := before.session_state_to_dict()

	# The next build dropped `gate_yard` and added `new_region`.
	var reauthored := MapZoneLayer.new()
	var region := ZoneAreaRecord.new()
	region.id = &"new_region"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.add_rect(Rect2i(0, 0, 2, 2))
	reauthored.areas.append(region)
	var after := MapZoneRegistry.new()
	after.build_from(reauthored)
	after.apply_session_state(snapshot) # carries owner for `gate_yard` and `forest`
	# Stale ids silently ignored: no crash, no resurrected zone.
	assert(after.state(&"gate_yard") == null)
	assert(after.state(&"forest") == null)
	assert(after.state(&"new_region") != null)
	assert(after.owner_of(&"new_region") == &"") # untouched by the stale snapshot
