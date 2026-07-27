class_name TestDomainHousingBlueprints
extends RefCounted

## Validates every shipped housing blueprint in content/core/buildings/housing/.
## Each file must be a v6 blueprint with exactly one core:housing room, one
## front_door, a correct footprint, residents > 0, and no fixtures/slots/
## storage/queues. The library must index every file from the nested folder.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const LibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")

const HOUSING_DIR := "res://game/content/core/buildings/housing"
const EXPECTED_IDS: Array[String] = [
	"tent_shelter", "dugout", "earth_cottage", "clay_cottage",
	"timber_house", "stone_house", "brick_house",
]


static func run_all() -> void:
	_test_every_housing_blueprint()
	_test_library_indexes_housing()


static func _test_every_housing_blueprint() -> void:
	var found_ids: Dictionary = {}
	for path in _housing_json_files():
		var text := FileAccess.get_file_as_string(path)
		assert(not text.is_empty(), "Could not read %s" % path)
		var json := JSON.new()
		assert(json.parse(text) == OK, "Invalid JSON in %s" % path)
		var raw: Dictionary = json.data

		var file_id := String(raw.get("id", ""))
		assert(file_id != "", "%s has no id" % path)
		assert(not found_ids.has(file_id), "Duplicate housing id: %s" % file_id)
		found_ids[file_id] = true

		# Version 6
		assert(int(raw.get("version", 0)) == 6,
			"%s: version must be 6, got %d" % [file_id, int(raw.get("version", 0))])

		# Exactly one home area
		var areas: Array = raw.get("areas", [])
		assert(areas.size() == 1, "%s: expected 1 area, got %d" % [file_id, areas.size()])
		var area: Dictionary = areas[0]
		assert(String(area.get("id", "")) == "home", "%s: area id must be 'home'" % file_id)
		assert(String(area.get("role", "")) == "room", "%s: home must be a room" % file_id)
		assert(String(area.get("function", "")) == "core:housing",
			"%s: home function must be core:housing" % file_id)
		var props: Dictionary = area.get("properties", {})
		assert(int(props.get("residents", 0)) > 0,
			"%s: residents must be > 0" % file_id)

		# Exactly one front_door anchor
		var anchors: Array = raw.get("anchors", [])
		assert(anchors.size() == 1, "%s: expected 1 anchor, got %d" % [file_id, anchors.size()])
		var anchor: Dictionary = anchors[0]
		assert(String(anchor.get("id", "")) == "front_door", "%s: anchor id must be 'front_door'" % file_id)
		assert(String(anchor.get("role", "")) == "door", "%s: front_door must be a door" % file_id)
		var allow: Array = anchor.get("allow", [])
		assert("builder" in allow, "%s: front_door must allow builder" % file_id)

		# No fixtures
		assert(raw.get("fixtures", []).size() == 0, "%s: must have no fixtures" % file_id)

		# No slots, storage, or queues among anchors
		for a in anchors:
			var role := String(a.get("role", ""))
			assert(role not in ["slot", "storage", "queue"],
				"%s: anchor %s has forbidden role %s" % [file_id, a.get("id", ""), role])

		# No routes
		assert(raw.get("routes", []).size() == 0, "%s: must have no routes" % file_id)

		# Footprint matches block extent
		var footprint: Array = raw.get("footprint", [0, 0])
		assert(footprint.size() == 2, "%s: footprint must be [w, h]" % file_id)
		var fp_w := int(footprint[0])
		var fp_h := int(footprint[1])
		assert(fp_w > 0 and fp_h > 0, "%s: footprint must be positive" % file_id)
		assert(fp_w == fp_h, "%s: footprint must be square" % file_id)
		var blocks: Array = raw.get("blocks", [])
		assert(blocks.size() == fp_w * fp_h,
			"%s: expected %d blocks for %dx%d footprint, got %d" % [file_id, fp_w * fp_h, fp_w, fp_h, blocks.size()])
		var covered: Dictionary = {}
		for block in blocks:
			var pos: Array = block.get("pos", [])
			assert(pos.size() == 3, "%s: block pos must be [x,y,z]" % file_id)
			var key := "%d,%d" % [int(pos[0]), int(pos[2])]
			assert(not covered.has(key), "%s: duplicate block at %s" % [file_id, key])
			covered[key] = true
			assert(int(pos[1]) == 0, "%s: block at %s must be at y=0" % [file_id, key])
		assert(covered.size() == fp_w * fp_h,
			"%s: blocks do not cover the full footprint" % file_id)

		# Full validation passes (from_json returns null on validation error)
		var bp := BuildingBlueprintScript.from_json(text)
		assert(bp != null, "%s: validation failed" % file_id)

		# runtime_zone_definitions returns one zone with core:housing
		var zones: Array = bp.runtime_zone_definitions()
		assert(zones.size() == 1, "%s: expected 1 runtime zone, got %d" % [file_id, zones.size()])
		assert(String(zones[0].get("function", "")) == "core:housing",
			"%s: runtime zone function must be core:housing" % file_id)

		# routing_anchor_definitions returns one door
		var route_anchors: Array = bp.routing_anchor_definitions()
		assert(route_anchors.size() == 1, "%s: expected 1 routing anchor, got %d" % [file_id, route_anchors.size()])
		assert(String(route_anchors[0].get("role", "")) == "door",
			"%s: routing anchor must be a door" % file_id)

	# All expected ids were found
	for expected_id in EXPECTED_IDS:
		assert(found_ids.has(expected_id), "Missing housing blueprint: %s" % expected_id)


static func _test_library_indexes_housing() -> void:
	LibraryScript.refresh()
	for expected_id in EXPECTED_IDS:
		var runtime_key := "core:" + expected_id
		assert(LibraryScript.has(runtime_key),
			"BuildingBlueprintLibrary did not index %s from housing/" % expected_id)
		var bp := LibraryScript.get_blueprint(runtime_key)
		assert(bp != null, "Library returned null for %s" % runtime_key)
		assert(bp.version == 6, "%s: library blueprint version must be 6" % runtime_key)


static func _housing_json_files() -> Array[String]:
	var result: Array[String] = []
	if not DirAccess.dir_exists_absolute(HOUSING_DIR):
		return result
	for file_name in DirAccess.get_files_at(HOUSING_DIR):
		if file_name.ends_with(".gdbuilding.json"):
			result.append(HOUSING_DIR + "/" + file_name)
	result.sort()
	return result
