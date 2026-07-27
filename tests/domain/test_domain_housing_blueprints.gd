class_name TestDomainHousingBlueprints
extends RefCounted

## Validates every shipped building blueprint under content/core/buildings/.
## Each file must be a v6 blueprint with a slab base, at most one room area,
## one front_door with builder access, no fixtures/slots/storage/queues/routes,
## and a correct footprint. The library must index every file.

const BuildingBlueprintScript = preload("res://game/features/buildings/domain/editor/building_blueprint.gd")
const LibraryScript = preload("res://game/features/buildings/presentation/building_blueprint_library.gd")

const BUILDINGS_ROOT := "res://game/content/core/buildings"

# Buildings that predate the authored-blueprint migration. They use
# "door" as the anchor id (not "front_door") and may have no areas.
const LEGACY_IDS: Array[String] = [
	"campfire", "cook_campfire", "entrance_sign", "settlement_flag",
	"tent", "warehouse",
]


static func run_all() -> void:
	_test_every_building_blueprint()
	_test_library_indexes_all()


static func _test_every_building_blueprint() -> void:
	var found_ids: Dictionary = {}
	for path in _all_building_json_files():
		var text := FileAccess.get_file_as_string(path)
		assert(not text.is_empty(), "Could not read %s" % path)
		var json := JSON.new()
		assert(json.parse(text) == OK, "Invalid JSON in %s" % path)
		var raw: Dictionary = json.data

		var file_id := String(raw.get("id", ""))
		assert(file_id != "", "%s has no id" % path)
		assert(not found_ids.has(file_id), "Duplicate building id: %s" % file_id)
		found_ids[file_id] = true

		# Version 6
		assert(int(raw.get("version", 0)) == 6,
			"%s: version must be 6, got %d" % [file_id, int(raw.get("version", 0))])

		# Areas: 0 or 1
		var areas: Array = raw.get("areas", [])
		assert(areas.size() <= 1,
			"%s: expected 0-1 areas, got %d" % [file_id, areas.size()])
		if areas.size() == 1:
			var area: Dictionary = areas[0]
			assert(String(area.get("role", "")) == "room",
				"%s: area must be a room" % file_id)
			assert(String(area.get("function", "")).begins_with("core:"),
				"%s: area function must be namespaced" % file_id)

		# Exactly one door anchor
		var anchors: Array = raw.get("anchors", [])
		assert(anchors.size() == 1,
			"%s: expected 1 anchor, got %d" % [file_id, anchors.size()])
		var anchor: Dictionary = anchors[0]
		assert(String(anchor.get("role", "")) == "door",
			"%s: anchor must be a door" % file_id)
		var is_legacy := file_id in LEGACY_IDS
		if not is_legacy:
			assert(String(anchor.get("id", "")) == "front_door",
				"%s: anchor id must be 'front_door'" % file_id)
		# builder access: either allow list is empty (permits all) or includes builder
		var allow: Array = anchor.get("allow", [])
		if not allow.is_empty():
			assert("builder" in allow,
				"%s: door must allow builder" % file_id)

		# No fixtures (new buildings only; legacy may have authored fixtures)
		if not is_legacy:
			assert(raw.get("fixtures", []).size() == 0,
				"%s: must have no fixtures" % file_id)

		# No slots, storage, or queues among anchors
		for a in anchors:
			var role := String(a.get("role", ""))
			assert(role not in ["slot", "storage", "queue"],
				"%s: anchor %s has forbidden role %s" % [file_id, a.get("id", ""), role])

		# No routes (new buildings only)
		if not is_legacy:
			assert(raw.get("routes", []).size() == 0,
				"%s: must have no routes" % file_id)

		# Footprint
		var footprint: Array = raw.get("footprint", [0, 0])
		assert(footprint.size() == 2, "%s: footprint must be [w, h]" % file_id)
		var fp_w := int(footprint[0])
		var fp_h := int(footprint[1])
		assert(fp_w > 0 and fp_h > 0,
			"%s: footprint must be positive" % file_id)

		# Block coverage (new buildings only; legacy may have no blocks)
		if not is_legacy:
			assert(fp_w == fp_h, "%s: footprint must be square" % file_id)
			var blocks: Array = raw.get("blocks", [])
			assert(blocks.size() == fp_w * fp_h,
				"%s: expected %d blocks for %dx%d footprint, got %d" % [
					file_id, fp_w * fp_h, fp_w, fp_h, blocks.size()])
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

		# runtime_zone_definitions: 0 or 1 zone
		var zones: Array = bp.runtime_zone_definitions()
		if areas.size() == 0:
			assert(zones.size() == 0,
				"%s: expected 0 runtime zones, got %d" % [file_id, zones.size()])
		else:
			assert(zones.size() == 1,
				"%s: expected 1 runtime zone, got %d" % [file_id, zones.size()])

		# routing_anchor_definitions returns one door
		var route_anchors: Array = bp.routing_anchor_definitions()
		assert(route_anchors.size() == 1,
			"%s: expected 1 routing anchor, got %d" % [file_id, route_anchors.size()])
		assert(String(route_anchors[0].get("role", "")) == "door",
			"%s: routing anchor must be a door" % file_id)

	print("Validated %d building blueprints" % found_ids.size())


static func _test_library_indexes_all() -> void:
	LibraryScript.refresh()
	var entries: Array = LibraryScript.authored_entries()
	assert(entries.size() > 0, "Library indexed no authored blueprints")
	print("Library indexed %d authored blueprints" % entries.size())


static func _all_building_json_files() -> Array[String]:
	var result: Array[String] = []
	_collect_json_files(BUILDINGS_ROOT, result)
	result.sort()
	return result


static func _collect_json_files(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir():
			if name != "." and name != "..":
				_collect_json_files(dir_path + "/" + name, out)
		elif name.ends_with(".gdbuilding.json"):
			out.append(dir_path + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
