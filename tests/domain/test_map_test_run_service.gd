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


## A settlement map with nowhere for the party to appear fails the preflight, and
## the editor surfaces that before the scene swap rather than after it.
static func _test_settlement_without_party_spawns_reports_errors() -> void:
	var document := MapDocument.create(&"settle", "Settle", BOARD_CELLS)
	var service := MapTestRunService.new()
	var errors := service.validate_session(document, &"core:settlement")
	assert(not errors.is_empty(), "a settlement with no entrance should not launch")
	assert(errors.any(func(m: String) -> bool: return m.contains("варианта старта")),
		"the missing entrance is what is reported: %s" % "; ".join(errors))


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
## must not require dragging the party's places there and back.
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
	twin.id = &"leader_point" # already taken by the party's leader place
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
	var leader := ZoneAnchorRecord.new()
	leader.id = &"leader_point"
	leader.role = ZoneAnchorRecord.ROLE_SPAWN
	leader.function = MapSpawnService.PARTY_LEADER
	leader.pos = Vector3(0.5, 0.0, 0.5)
	document.zones.anchors.append(leader)
	# One authored place and a clearing: the party size is a launch parameter now,
	# so the map does not carry one anchor per settler (`map_start.md` §5.3).
	var clearing := ZoneAreaRecord.new()
	clearing.id = &"clearing"
	clearing.role = ZoneAreaRecord.ROLE_REGION
	clearing.add_rect(Rect2i(-4, -4, 8, 8))
	document.zones.areas.append(clearing)
	var group := MapSpawnGroup.new()
	group.id = &"camp"
	group.area_id = &"clearing"
	group.spacing = 1.0
	var slot := MapSpawnGroup.Slot.new()
	slot.id = &"leader"
	slot.anchor_id = &"leader_point"
	slot.tags = [MapSpawnGroup.TAG_LEADER]
	group.slots.append(slot)
	document.zones.spawn_groups.append(group)
	var option := MapStartOption.new()
	option.id = &"default"
	option.spawn_group = &"camp"
	document.meta.start.starts.append(option)
	document.meta.start.default_start = &"default"
	return document
