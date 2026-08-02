class_name TestMapTestRunService
extends RefCounted

## Domain tests for the editor test-run preflight (`MapTestRunService`).
## `validate_session` mirrors what `SessionBootstrapper.run` checks, but without
## changing scenes, so the editor reports a missing `core:hero_start` in the
## status bar instead of leaving the author on a black screen after launch.

const BOARD_CELLS := 16


static func run_all() -> void:
	_test_settlement_without_party_spawns_reports_errors()
	_test_settlement_with_complete_party_is_launchable()
	_test_showcase_without_spawns_is_launchable()
	_test_unknown_game_definition_reports_error()
	_test_spawn_override_launches_a_half_drawn_map()
	_test_preflight_runs_the_zone_layer_rules()
	print("    [PASS] Map Test Run Service Tests")


## A settlement map with no spawn anchors fails the preflight: launch needs a
## `core:hero_start` and companion starts, and the editor must surface that
## before the scene swap.
static func _test_settlement_without_party_spawns_reports_errors() -> void:
	var document := MapDocument.create(&"settle", "Settle", BOARD_CELLS)
	var service := MapTestRunService.new()
	var errors := service.validate_session(document, &"core:settlement")
	assert(not errors.is_empty(), "settlement without hero_start should not launch")
	assert(errors.any(func(m: String) -> bool: return m.find("hero_start") > 0),
		"missing hero_start reported: %s" % "; ".join(errors))


## A settlement map that authors the full starting party clears the preflight.
static func _test_settlement_with_complete_party_is_launchable() -> void:
	var document := _settlement_with_party(BOARD_CELLS)
	var service := MapTestRunService.new()
	var errors := service.validate_session(document, &"core:settlement")
	assert(errors.is_empty(), "complete settlement party should launch: %s" % "; ".join(errors))


## World Showcase has no starting party, so a map without spawn anchors must
## still launch — the preflight must not impose settlement-only rules on every
## game definition.
static func _test_showcase_without_spawns_is_launchable() -> void:
	var document := MapDocument.create(&"show", "Show", BOARD_CELLS)
	var service := MapTestRunService.new()
	var errors := service.validate_session(document, &"core:world_showcase")
	assert(errors.is_empty(), "showcase needs no spawns: %s" % "; ".join(errors))


## A game definition the installed packs do not provide is reported, not
## silently turned into an empty error list.
static func _test_unknown_game_definition_reports_error() -> void:
	var document := MapDocument.create(&"any", "Any", BOARD_CELLS)
	var service := MapTestRunService.new()
	var errors := service.validate_session(document, &"core:not_installed")
	assert(not errors.is_empty(), "unknown game definition should be reported")


## "Тест отсюда" (Shift+F5) brings its own party start, so the map does not need
## authored spawn anchors for it. This is the whole feature: checking a far corner
## must not require dragging `core:hero_start` there and back.
static func _test_spawn_override_launches_a_half_drawn_map() -> void:
	var document := MapDocument.create(&"settle", "Settle", BOARD_CELLS)
	var service := MapTestRunService.new()
	assert(not service.validate_session(document, &"core:settlement").is_empty(),
		"a plain F5 still demands the authored party")
	assert(service.validate_session(document, &"core:settlement", true).is_empty(),
		"a run from the cursor does not")


## The check button, F5 and save must answer the same question. While the
## preflight skipped `MapZoneLayer.validate`, a duplicate zone id reported "no
## errors", launched, and then refused to save.
static func _test_preflight_runs_the_zone_layer_rules() -> void:
	var document := _settlement_with_party(BOARD_CELLS)
	var twin := ZoneAnchorRecord.new()
	twin.id = &"hero_start" # already taken by the party's hero start
	twin.role = ZoneAnchorRecord.ROLE_WAYPOINT
	twin.pos = Vector3(2.5, 0.0, 2.5)
	document.zones.anchors.append(twin)

	var service := MapTestRunService.new()
	var result := service.validate(document, null)
	var errors: Array = result["errors"]
	assert(errors.any(func(m: String) -> bool: return m.find("дублирующийся id") >= 0),
		"the preflight sees what save sees: %s" % "; ".join(errors))


static func _settlement_with_party(board_cells: int) -> MapDocument:
	var document := MapDocument.create(&"party", "Party", board_cells)
	var hero := ZoneAnchorRecord.new()
	hero.id = &"hero_start"
	hero.role = ZoneAnchorRecord.ROLE_SPAWN
	hero.function = MapSpawnService.HERO_START
	hero.pos = Vector3(0.5, 0.0, 0.5)
	document.zones.anchors.append(hero)
	# Default starting population is 4, so three companion starts complete it.
	for index in 3:
		var companion := ZoneAnchorRecord.new()
		companion.id = StringName("companion_%d" % index)
		companion.role = ZoneAnchorRecord.ROLE_SPAWN
		companion.function = MapSpawnService.COMPANION_START
		companion.pos = Vector3(1.5 + index, 0.0, 0.5)
		document.zones.anchors.append(companion)
	return document
