class_name TestMapDocument
extends RefCounted

## The `.gdmap` package: write → read → byte-for-byte equal
## (design_docs/engine/map_editor.md §15 "Тесты").
##
## The round-trip is the load-bearing test of the whole format. A map is the one
## artefact a player spends hours on and cannot reconstruct, so every claim the
## format makes has to be asserted rather than assumed: that a saved board comes
## back identical, that an untouched layer costs no file, that a section this
## build does not understand survives being opened and saved by it, and that a
## half-written package can never replace a good one.

const TEST_ROOT := "user://test_maps"
const BOARD_CELLS := 32


static func run_all() -> void:
	_test_meta_round_trips_through_json()
	_test_start_defaults_and_system_flags()
	_test_border_level_migrates_from_version_one()
	_test_legacy_zone_sections_migrate_to_v3()
	print("    [PASS] Map Meta Tests")
	_test_write_target_follows_the_mode()
	print("    [PASS] Map Write Target Tests")
	_test_terrain_layer_round_trips_byte_for_byte()
	_test_default_board_writes_no_layer()
	_test_foreign_or_truncated_layer_is_refused()
	print("    [PASS] Map Terrain Codec Tests")
	_test_package_round_trip_on_disk()
	_test_zone_layer_round_trips()
	_test_zone_layer_reports_structural_errors()
	_test_zone_layer_reports_warnings()
	_test_unknown_sections_survive_a_save()
	_test_save_replaces_the_package_atomically()
	_test_runtime_keys_namespace_player_maps()
	print("    [PASS] Map Package Tests")
	_cleanup()


# --- Meta ---------------------------------------------------------------------

static func _test_meta_round_trips_through_json() -> void:
	var document := MapDocument.create(&"green_valley", "Зелёная долина", BOARD_CELLS)
	document.meta.author = "ivan"
	document.meta.map_kind = MapMeta.MAP_KIND_SCENARIO
	document.meta.players = 4
	document.meta.biomes = [&"forest", &"mountain"]
	document.meta.tags = [&"survival"]
	document.meta.border_level = -2
	document.meta.border_kind = MapMeta.BORDER_NOTHING
	document.meta.start.era = &"tent"
	document.meta.start.style = &"roman"
	document.meta.start.day_of_year = 200
	document.meta.start.latitude = 60.0
	document.meta.start.time_of_day = 540
	document.meta.start.mode_id = MapStart.MODE_HERO
	document.meta.start.systems = {"settlement_sim": false, "hero_control": "first_person"}
	document.meta.start.economy = {"money": 900, "population": 2}
	document.meta.required_content = [{"kind": "building", "source": "player", "id": "my_bakery"}]

	var restored := MapDocument.from_json(document.to_json())
	assert(restored.meta.id == &"green_valley")
	assert(restored.meta.name == "Зелёная долина")
	assert(restored.meta.author == "ivan")
	assert(restored.meta.map_kind == MapMeta.MAP_KIND_SCENARIO)
	assert(restored.meta.players == 4)
	assert(restored.meta.biomes == [&"forest", &"mountain"])
	assert(restored.meta.tags == [&"survival"])
	assert(restored.meta.board_cells == BOARD_CELLS)
	assert(restored.meta.border_level == -2)
	assert(restored.meta.border_kind == MapMeta.BORDER_NOTHING)
	assert(restored.meta.start.day_of_year == 200)
	assert(restored.meta.start.style == &"roman")
	assert(is_equal_approx(restored.meta.start.latitude, 60.0))
	assert(restored.meta.start.time_of_day == 540)
	assert(restored.meta.start.mode_id == MapStart.MODE_HERO)
	assert(restored.meta.start.hero_control() == MapStart.HERO_CONTROL_FIRST_PERSON)
	assert(restored.meta.required_content.size() == 1)
	assert(restored.meta.start.economy["money"] == 900)
	assert(restored.to_json()["format_version"] == MapMeta.FORMAT_VERSION)


## v1 wrote `border.level` as a float; v2 made it whole Δh steps. Reading a v1 file
## as an int would truncate — a sea half a terrace lower than the author left it,
## silently frozen in place by the next save.
static func _test_border_level_migrates_from_version_one() -> void:
	var service := _service()
	var package := _package_path("legacy_border")
	DirAccess.make_dir_recursive_absolute(package)
	var legacy := {
		"format_version": 1, "kind": "map", "id": "legacy_border", "name": "Старая",
		"board": {"cells": BOARD_CELLS, "cell_size": 1.0},
		"border": {"kind": "ocean", "level": -1.5},
	}
	var file := FileAccess.open(package.path_join(MapDocumentService.MAP_JSON), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	var loaded := service.load_package(package)
	assert(loaded != null, "a v1 package still opens")
	assert(loaded.meta.border_level == -2, "-1.5 rounds to the nearer step, not toward zero: %d" % loaded.meta.border_level)

	# ...and the rounded value is what a resave writes, so the migration happens
	# once instead of drifting on every open.
	assert(loaded.to_json()["border"]["level"] == -2)
	assert(loaded.to_json()["format_version"] == MapMeta.FORMAT_VERSION)
	_cleanup()


## v2 stored `regions`/`markers` as opaque passthrough; v3 promotes records that
## already have the shared zone shape into the typed `areas`/`anchors`. A record
## the migration cannot understand stays opaque (§18.1) rather than guessed at —
## guessing a role would silently change a player's scenario.
static func _test_legacy_zone_sections_migrate_to_v3() -> void:
	var service := _service()
	var package := _package_path("legacy_zones")
	DirAccess.make_dir_recursive_absolute(package)
	var legacy := {
		"format_version": 2, "kind": "map", "id": "legacy_zones", "name": "Старые зоны",
		"board": {"cells": BOARD_CELLS, "cell_size": 1.0},
		# A region already shaped like a v3 area: id + role + rects.
		"regions": [{"id": "gate_yard", "role": "region", "rects": [[2, 3, 4, 2]]}],
		# A marker already shaped like a v3 anchor: id + role + pos.
		"markers": [{"id": "hero_start", "role": "spawn", "pos": [2.5, 0.0, 3.5]}],
		# A marker the migration cannot understand (no `pos`): must survive opaque,
		# because guessing its meaning would change the player's map silently.
		"markers_unknown": [{"id": "old_trigger", "kind": "ambience"}],
	}
	var file := FileAccess.open(package.path_join(MapDocumentService.MAP_JSON), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()

	var loaded := service.load_package(package)
	assert(loaded != null, "a v2 package with legacy zones still opens")
	# The well-formed records were promoted into the typed layer...
	assert(loaded.zones.area_by_id(&"gate_yard") != null, "region promoted to area")
	assert(loaded.zones.anchor_by_id(&"hero_start") != null, "marker promoted to anchor")
	assert(loaded.zones.validate(BOARD_CELLS).is_empty())
	# ...and the legacy keys no longer appear in a resave.
	var resaved := loaded.to_json()
	assert(not resaved.has("regions"), "regions consumed by migration, not duplicated")
	assert(not resaved.has("markers"), "markers consumed by migration, not duplicated")
	assert(resaved.has("areas") and resaved["areas"].size() == 1)
	assert(resaved.has("anchors") and resaved["anchors"].size() == 1)
	assert(resaved["format_version"] == MapMeta.FORMAT_VERSION)
	# The un-understood marker survived as an opaque section.
	assert(loaded.section("markers_unknown").size() == 1)
	_cleanup()


## Which folder a save lands in is decided by the mode, never by the document
## (content_packaging.md §6.4). Player mode must not be able to name a path inside
## the shipped pack as its own.
static func _test_write_target_follows_the_mode() -> void:
	var player := MapDocumentService.new(false)
	assert(player.target_source() == MapDocumentService.SOURCE_PLAYER)
	assert(player.base_dir() == MapDocumentService.PLAYER_ROOT)
	assert(player.can_write(MapDocumentService.PLAYER_ROOT + "/mine.gdmap"))
	assert(not player.can_write(MapDocumentService.BUILTIN_ROOT + "/green_valley.gdmap"),
		"a player may open the shipped map but never write it")

	# Dev mode is the mirror image, and only exists inside Godot: in an exported
	# build `res://` is a read-only `.pck`, so the flag is refused outright.
	var dev := MapDocumentService.new(true)
	if OS.has_feature("editor"):
		assert(dev.target_source() == MapDocumentService.SOURCE_BUILTIN)
		assert(dev.can_write(MapDocumentService.BUILTIN_ROOT + "/green_valley.gdmap"))
		assert(not dev.can_write(MapDocumentService.PLAYER_ROOT + "/mine.gdmap"))
	else:
		assert(not dev.dev_mode, "dev mode cannot survive outside the Godot editor")

	# An id outside the alphabet never reaches the filesystem.
	var document := MapDocument.create(&"Карта", "Кириллица", BOARD_CELLS)
	assert(player.save_map(document).is_empty(), "a non-ASCII id is refused")
	assert(not player.last_error.is_empty(), "and says why")


## A system a map never mentions must keep running. Otherwise adding a flag to the
## format would silently switch that system off in every map authored before it.
static func _test_start_defaults_and_system_flags() -> void:
	var start := MapStart.from_dict({})
	assert(start.mode_id == MapStart.MODE_SETTLEMENT)
	assert(start.time_of_day == MapStart.DEFAULT_TIME_OF_DAY)
	assert(start.is_system_enabled(&"a_system_invented_next_year"))
	assert(start.hero_control() == MapStart.HERO_CONTROL_THIRD_PERSON)

	var shooter := MapStart.from_dict({
		"mode": {"id": "hero", "systems": {"settlement_sim": false, "hero_control": "first_person"}},
	})
	assert(not shooter.is_system_enabled(&"settlement_sim"))
	assert(shooter.is_system_enabled(&"needs"))
	assert(shooter.hero_control() == MapStart.HERO_CONTROL_FIRST_PERSON)

	# Board sizes are whole chunks or they are not board sizes.
	assert(MapMeta.is_valid_board_size(MapMeta.PRESET_STANDARD))
	assert(not MapMeta.is_valid_board_size(96 + 1))
	assert(not MapMeta.is_valid_board_size(0))


# --- Terrain layer ------------------------------------------------------------

static func _authored_grid() -> TerrainGrid:
	var grid := TerrainGrid.new()
	grid.configure(1.0, BOARD_CELLS)
	# One of everything the layer has to carry: height, material, every detail
	# field, both flags, and a ramp with a direction and an index.
	for z in range(-4, 4):
		for x in range(-4, 4):
			grid.set_height(Vector2i(x, z), 3)
			grid.set_material(Vector2i(x, z), TerrainMaterialCatalog.STONE)
	grid.set_variant(Vector2i(0, 0), 2)
	grid.set_wear(Vector2i(1, 0), TerrainDetailCodec.MAX_WEAR)
	grid.set_snow_depth(Vector2i(2, 0), TerrainDetailCodec.MAX_SNOW_DEPTH)
	grid.set_hole(Vector2i(3, 0), true)
	grid.set_anchor(Vector2i(-3, 0), true)
	grid.set_height(Vector2i(-8, -8), -12)
	grid.place_ramp(Vector2i(-8, 0), SlopeCatalog.SHALLOW, SlopeCatalog.DIR_E)
	return grid


static func _test_terrain_layer_round_trips_byte_for_byte() -> void:
	var source := _authored_grid()
	var bytes := MapTerrainCodec.encode(source)
	assert(MapTerrainCodec.is_valid(bytes))
	assert(MapTerrainCodec.board_cells_of(bytes) == BOARD_CELLS)
	assert(bytes.size() == MapTerrainCodec.HEADER_BYTES + BOARD_CELLS * BOARD_CELLS * MapTerrainCodec.BYTES_PER_CELL)

	var restored := TerrainGrid.new()
	restored.configure(1.0, BOARD_CELLS)
	assert(MapTerrainCodec.decode_into(bytes, restored))

	var before := source.snapshot()
	var after := restored.snapshot()
	for key: String in before:
		assert(before[key] == after[key])
	# And re-encoding the restored grid gives the same file, which is the property
	# that actually keeps a map stable across an open-and-save that changed nothing.
	assert(MapTerrainCodec.encode(restored) == bytes)


static func _test_default_board_writes_no_layer() -> void:
	var flat := TerrainGrid.new()
	flat.configure(1.0, BOARD_CELLS)
	assert(MapTerrainCodec.is_default(flat))
	assert(MapTerrainCodec.encode(flat).is_empty())
	# ...but it is still encodable when a caller insists.
	assert(not MapTerrainCodec.encode(flat, false).is_empty())

	flat.set_height(Vector2i(0, 0), 1)
	assert(not MapTerrainCodec.is_default(flat))
	assert(not MapTerrainCodec.encode(flat).is_empty())


## A layer that does not belong to this board must be refused whole. Loading half
## of it would leave a world whose ground is partly someone else's.
static func _test_foreign_or_truncated_layer_is_refused() -> void:
	var bytes := MapTerrainCodec.encode(_authored_grid())

	var wrong_board := TerrainGrid.new()
	wrong_board.configure(1.0, BOARD_CELLS * 2)
	assert(not MapTerrainCodec.decode_into(bytes, wrong_board))

	var truncated := bytes.slice(0, bytes.size() - MapTerrainCodec.BYTES_PER_CELL)
	assert(not MapTerrainCodec.is_valid(truncated))
	var target := TerrainGrid.new()
	target.configure(1.0, BOARD_CELLS)
	assert(not MapTerrainCodec.decode_into(truncated, target))
	assert(MapTerrainCodec.is_default(target))

	var foreign := bytes.duplicate()
	foreign[0] = "X".unicode_at(0)
	assert(not MapTerrainCodec.is_valid(foreign))
	assert(not MapTerrainCodec.decode_into(PackedByteArray(), target))


# --- Package ------------------------------------------------------------------

static func _service() -> MapDocumentService:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	return MapDocumentService.new()


static func _package_path(id: String) -> String:
	return TEST_ROOT.path_join(id + MapDocumentService.PACKAGE_SUFFIX)


static func _save_to(service: MapDocumentService, document: MapDocument) -> String:
	# The service addresses packages by source; the test drives the same writer at
	# a scratch root so it never touches the player's real maps.
	return service.save_map_to(document, _package_path(String(document.meta.id)))


static func _test_package_round_trip_on_disk() -> void:
	var service := _service()
	var document := MapDocument.create(&"round_trip", "Круг", BOARD_CELLS)
	document.terrain = _authored_grid()
	document.meta.start.economy = {"money": 42}
	var revision_before := document.meta.revision

	var path := _save_to(service, document)
	assert(not path.is_empty())
	assert(FileAccess.file_exists(path.path_join(MapDocumentService.MAP_JSON)))
	assert(FileAccess.file_exists(path.path_join(MapDocumentService.TERRAIN_BIN)))
	# Saving stamps a new revision and clears the dirty flag.
	assert(document.meta.revision != revision_before)
	assert(not document.dirty)

	var loaded := service.load_package(path)
	assert(loaded != null)
	assert(loaded.meta.name == "Круг")
	assert(loaded.meta.board_cells == BOARD_CELLS)
	assert(loaded.meta.revision == document.meta.revision)
	assert(loaded.meta.start.economy["money"] == 42)
	assert(not loaded.dirty)
	assert(MapTerrainCodec.encode(loaded.terrain) == MapTerrainCodec.encode(document.terrain))

	# A flat map writes no terrain layer, and loading it back gives a flat board
	# rather than a failure.
	var empty := MapDocument.create(&"empty", "Пусто", BOARD_CELLS)
	var empty_path := _save_to(service, empty)
	assert(not FileAccess.file_exists(empty_path.path_join(MapDocumentService.TERRAIN_BIN)))
	var empty_loaded := service.load_package(empty_path)
	assert(empty_loaded != null)
	assert(MapTerrainCodec.is_default(empty_loaded.terrain))

	assert(service.load_package(TEST_ROOT.path_join("no_such.gdmap")) == null)
	assert(not service.last_error.is_empty())


## `areas`, `anchors` and `routes` are authored data, not opaque future sections:
## their IDs and references must survive the exact same package round trip.
static func _test_zone_layer_round_trips() -> void:
	var document := MapDocument.create(&"zones", "Зоны", BOARD_CELLS)
	var region := ZoneAreaRecord.new()
	region.id = &"gate_yard"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.add_rect(Rect2i(2, 3, 4, 2))
	document.zones.areas.append(region)
	var spawn := ZoneAnchorRecord.new()
	spawn.id = &"hero_start"
	spawn.role = ZoneAnchorRecord.ROLE_SPAWN
	spawn.pos = Vector3(2.5, 0.0, 3.5)
	spawn.function = &"core:hero_start"
	document.zones.anchors.append(spawn)
	var route := ZoneRouteRecord.new()
	route.id = &"patrol"
	route.stops = [&"hero_start"]
	document.zones.routes.append(route)

	var restored := MapDocument.from_json(document.to_json())
	assert(restored.zones.area_by_id(&"gate_yard") != null)
	assert(restored.zones.anchor_by_id(&"hero_start").function == &"core:hero_start")
	assert(restored.zones.route_by_id(&"patrol").stops == [&"hero_start"])
	assert(restored.zones.validate(BOARD_CELLS).is_empty())


## §8.1: structural errors that must block save — id outside the `ContentId`
## alphabet (§8.1), and a point whose height is outside its owner area's y-range.
## Both are file-will-not-launch errors, so they surface from `validate()`.
static func _test_zone_layer_reports_structural_errors() -> void:
	var document := MapDocument.create(&"zones", "Зоны", BOARD_CELLS)
	# An area with a narrow y-band, then an owned point above that band.
	var region := ZoneAreaRecord.new()
	region.id = &"yard"
	region.role = ZoneAreaRecord.ROLE_REGION
	region.y_min = 0
	region.y_max = 0
	region.add_rect(Rect2i(2, 3, 4, 2))
	document.zones.areas.append(region)
	var floating := ZoneAnchorRecord.new()
	floating.id = &"post"
	floating.role = ZoneAnchorRecord.ROLE_WAYPOINT
	floating.owner_id = &"yard"
	floating.pos = Vector3(3.5, 5.0, 4.5) # y=5, but the yard spans y=[0,0]
	document.zones.anchors.append(floating)
	# A point with a non-ASCII id — outside the `ContentId` alphabet.
	var bad_id := ZoneAnchorRecord.new()
	bad_id.id = &"Вход"
	bad_id.role = ZoneAnchorRecord.ROLE_SPAWN
	bad_id.pos = Vector3(2.5, 0.0, 3.5)
	document.zones.anchors.append(bad_id)

	var errors := document.zones.validate(BOARD_CELLS)
	assert(errors.any(func(message: String) -> bool: return message.find("y") > 0),
		"point above owner y-range is a launch error: %s" % "; ".join(errors))
	assert(errors.any(func(message: String) -> bool: return message.find("алфавит") > 0),
		"non-ASCII id is a launch error: %s" % "; ".join(errors))


## §8.2: warnings — a map launches with these but the author very likely did not
## mean them. They must NOT surface from `validate()` (which blocks save), only
## from `warnings()`. A region nothing references warns; an overlay does not,
## because an overlay changes a calculation rather than being pointed at.
static func _test_zone_layer_reports_warnings() -> void:
	var document := MapDocument.create(&"zones_warn", "Зоны", BOARD_CELLS)
	# A region no anchor owns and no route touches — an orphan.
	var orphan := ZoneAreaRecord.new()
	orphan.id = &"lonely_region"
	orphan.role = ZoneAreaRecord.ROLE_REGION
	orphan.add_rect(Rect2i(2, 2, 2, 2))
	document.zones.areas.append(orphan)
	# A region that IS referenced (by an owned anchor) — no warning.
	var used := ZoneAreaRecord.new()
	used.id = &"yard"
	used.role = ZoneAreaRecord.ROLE_REGION
	used.add_rect(Rect2i(8, 8, 2, 2))
	document.zones.areas.append(used)
	var post := ZoneAnchorRecord.new()
	post.id = &"post"
	post.role = ZoneAnchorRecord.ROLE_WAYPOINT
	post.owner_id = &"yard"
	post.pos = Vector3(8.5, 0.0, 8.5)
	document.zones.anchors.append(post)
	# An overlay — never warns for being unreferenced, that is its nature.
	var overlay := ZoneAreaRecord.new()
	overlay.id = &"forest"
	overlay.role = ZoneAreaRecord.ROLE_OVERLAY
	overlay.effects = {ZoneEffects.KEY_COST: 2.0}
	overlay.add_rect(Rect2i(0, 0, 2, 2))
	document.zones.areas.append(overlay)

	var warnings := document.zones.warnings(BOARD_CELLS)
	assert(warnings.any(func(message: String) -> bool: return message.find("lonely_region") > 0),
		"orphan region warns: %s" % "; ".join(warnings))
	assert(not warnings.any(func(message: String) -> bool: return message.find("yard") > 0),
		"referenced region does not warn")
	assert(not warnings.any(func(message: String) -> bool: return message.find("forest") > 0),
		"overlay never warns for being unreferenced")
	# And the same layer has zero launch errors — warnings are not errors.
	assert(document.zones.validate(BOARD_CELLS).is_empty())


## The reason `MapDocument` carries sections it cannot interpret: a phase-1 editor
## must not eat the rules of a map authored in phase 5.
static func _test_unknown_sections_survive_a_save() -> void:
	var service := _service()
	var path := _package_path("from_the_future")
	DirAccess.make_dir_recursive_absolute(path)
	var future := {
		"format_version": 1,
		"kind": "map",
		"id": "from_the_future",
		"name": "Из будущего",
		"board": {"cells": BOARD_CELLS, "cell_size": 1.0},
		"rules": [{"id": "gate_ambush", "when": {"trigger": "region_entered"}, "once": true}],
		"markers": [{"id": "hero_start", "cell": [3, 4], "role": "hero_start"}],
		"a_section_from_2030": {"nested": [1, 2, 3]},
	}
	var file := FileAccess.open(path.path_join(MapDocumentService.MAP_JSON), FileAccess.WRITE)
	file.store_string(JSON.stringify(future))
	file.close()

	var loaded := service.load_package(path)
	assert(loaded != null)
	assert(loaded.section("rules").size() == 1)
	assert(loaded.section("markers").size() == 1)

	# Open, edit only the ground, save. Everything else has to come back.
	loaded.terrain.set_height(Vector2i(0, 0), 4)
	_save_to(service, loaded)
	var reloaded := service.load_package(path)
	assert(reloaded != null)
	assert(reloaded.section("rules")[0]["id"] == "gate_ambush")
	assert(reloaded.section("markers")[0]["role"] == "hero_start")
	# Note the shape, not the exact numbers: JSON has one number type, so a
	# passthrough section comes back with floats where it went in with ints. That
	# is survivable precisely because this build never interprets the values — it
	# reads them and writes them back.
	var future_section: Dictionary = reloaded.sections["a_section_from_2030"]
	assert((future_section["nested"] as Array).size() == 3)
	assert(reloaded.terrain.height_of(Vector2i(0, 0)) == 4)

	# A file from a format newer than this build is refused rather than guessed at.
	future["format_version"] = MapMeta.FORMAT_VERSION + 1
	var newer := FileAccess.open(path.path_join(MapDocumentService.MAP_JSON), FileAccess.WRITE)
	newer.store_string(JSON.stringify(future))
	newer.close()
	assert(service.load_package(path) == null)
	assert(not service.last_error.is_empty())


## The package on disk is either the old map or the new one, never a mixture.
static func _test_save_replaces_the_package_atomically() -> void:
	var service := _service()
	var document := MapDocument.create(&"atomic", "Атом", BOARD_CELLS)
	document.terrain = _authored_grid()
	var path := _save_to(service, document)
	var first_revision := document.meta.revision

	# A second save over a package that already has a terrain layer, this time of
	# a flat board: the stale layer must be gone, not left behind next to the new
	# map.json.
	var flat := MapDocument.create(&"atomic", "Атом 2", BOARD_CELLS)
	_save_to(service, flat)
	assert(not FileAccess.file_exists(path.path_join(MapDocumentService.TERRAIN_BIN)))
	assert(not DirAccess.dir_exists_absolute(path + ".tmp"))
	assert(not DirAccess.dir_exists_absolute(path + ".old"))

	var loaded := service.load_package(path)
	assert(loaded.meta.name == "Атом 2")
	assert(loaded.meta.revision != first_revision)
	assert(MapTerrainCodec.is_default(loaded.terrain))


static func _test_runtime_keys_namespace_player_maps() -> void:
	assert(MapDocumentService.runtime_key(MapDocumentService.SOURCE_BUILTIN, &"green_valley") == &"core:green_valley")
	assert(MapDocumentService.runtime_key(MapDocumentService.SOURCE_PLAYER, &"green_valley") == &"user:green_valley")

	# A player map can never be mistaken for the shipped map of the same name.
	var builtin := MapDocumentService.split_key(&"core:green_valley")
	assert(builtin["source"] == MapDocumentService.SOURCE_BUILTIN and builtin["id"] == &"green_valley")
	var player := MapDocumentService.split_key(&"user:green_valley")
	assert(player["source"] == MapDocumentService.SOURCE_PLAYER and player["id"] == &"green_valley")
	assert(MapDocumentService.split_key(&"green_valley")["id"] == &"", "map references require an explicit source")
	assert(MapDocumentService.package_path(MapDocumentService.SOURCE_PLAYER, &"green_valley").begins_with(MapDocumentService.PLAYER_ROOT))


static func _cleanup() -> void:
	MapDocumentService._remove_directory(TEST_ROOT)
