class_name FixtureEditorPanel
extends RefCounted

## Fixture editor sub-panel of fill mode (Phase 2A — fire_source vertical slice).
##
## Owns the fixture list, inspector, CRUD operations, and fire-source defaults.
## Extracted from BuildingFillModeController to isolate fixture concerns from fill
## object placement and selection.

const FixtureDefinitionScript = preload("res://game/features/buildings/domain/editor/fixture_definition.gd")
const FireSourceDefaultsScript = preload("res://game/features/buildings/domain/editor/fire_source_defaults.gd")

var _editor: Node = null

var _fixture_list: ItemList = null
var _fixture_id_label: Label = null
var _fixture_cap_option: OptionButton = null
var _fixture_visual_option: OptionButton = null
var _fixture_zone_option: OptionButton = null
var _fixture_fire_defaults_lbl: Label = null
var _fixture_fire_grid: GridContainer = null
var _fixture_lit_check: CheckBox = null
var _fixture_fuel_spin: SpinBox = null
var _fixture_cap_fuel_spin: SpinBox = null
var _selected_fixture_index: int = -1

## Guards the fixture inspector's own writes from re-entering as user edits.
var _syncing_ui: bool = false


## История принадлежит `BuildingEditor`: снимок чертежа делает `mark_dirty`
## после мутации, поэтому отдельного хука «запомни состояние» здесь нет.
func setup(editor: Node) -> void:
	_editor = editor

	_fixture_list = editor.get_node("%FixtureList")
	_fixture_id_label = editor.get_node("%FixtureIdLbl")
	_fixture_cap_option = editor.get_node("%FixtureCapabilityOption")
	_fixture_visual_option = editor.get_node("%FixtureVisualOption")
	_fixture_zone_option = editor.get_node("%FixtureZoneOption")
	_fixture_fire_defaults_lbl = editor.get_node("%FixtureFireDefaultsLbl")
	_fixture_fire_grid = editor.get_node("%FixtureFireGrid")
	_fixture_lit_check = editor.get_node("%FixtureLitCheck")
	_fixture_fuel_spin = editor.get_node("%FixtureFuelSpin")
	_fixture_cap_fuel_spin = editor.get_node("%FixtureCapFuelSpin")

	editor.get_node("%FixtureAddBtn").pressed.connect(add_fixture)
	editor.get_node("%FixtureDeleteBtn").pressed.connect(delete_fixture)
	_fixture_list.item_selected.connect(_on_fixture_list_selected)
	_fixture_cap_option.item_selected.connect(_on_fixture_capability_selected)
	_fixture_visual_option.item_selected.connect(_on_fixture_visual_selected)
	_fixture_zone_option.item_selected.connect(_on_fixture_zone_selected)
	_fixture_lit_check.toggled.connect(_on_fixture_fire_param_changed)
	_fixture_fuel_spin.value_changed.connect(_on_fixture_fire_param_changed)
	_fixture_cap_fuel_spin.value_changed.connect(_on_fixture_fire_param_changed)

	_build_fixture_capability_options()


func _build_fixture_capability_options() -> void:
	_fixture_cap_option.clear()
	for cap in FixtureDefinitionScript.KNOWN_CAPABILITIES:
		_fixture_cap_option.add_item(String(cap))
		_fixture_cap_option.set_item_metadata(_fixture_cap_option.item_count - 1, cap)


func _refresh_fixture_list() -> void:
	_syncing_ui = true
	_fixture_list.clear()
	var fixtures: Array = _editor.blueprint.fixtures
	for i in fixtures.size():
		var fixture: FixtureDefinitionScript = fixtures[i]
		var cap_text := "—"
		if not fixture.capabilities.is_empty():
			cap_text = String(fixture.capabilities[0])
		_fixture_list.add_item("%s (%s)" % [String(fixture.id), cap_text])
	if _selected_fixture_index >= 0 and _selected_fixture_index < fixtures.size():
		_fixture_list.select(_selected_fixture_index)
	else:
		_selected_fixture_index = -1
	_syncing_ui = false
	_refresh_fixture_inspector()


func _refresh_fixture_inspector() -> void:
	var fixtures: Array = _editor.blueprint.fixtures
	var has_selection := _selected_fixture_index >= 0 and _selected_fixture_index < fixtures.size()
	_fixture_id_label.visible = has_selection
	_fixture_cap_option.disabled = not has_selection
	_fixture_visual_option.disabled = not has_selection
	_fixture_zone_option.disabled = not has_selection
	_fixture_fire_defaults_lbl.visible = false
	_fixture_fire_grid.visible = false
	if not has_selection:
		_fixture_id_label.text = "ID: —"
		return
	var fixture: FixtureDefinitionScript = fixtures[_selected_fixture_index]
	_fixture_id_label.text = "ID: %s" % String(fixture.id)
	# Capability dropdown — select first capability.
	_syncing_ui = true
	var first_cap: Variant = fixture.capabilities[0] if not fixture.capabilities.is_empty() else ""
	for i in _fixture_cap_option.item_count:
		if _fixture_cap_option.get_item_metadata(i) == first_cap:
			_fixture_cap_option.select(i)
			break
	# Visual object dropdown — populate from blueprint objects.
	_fixture_visual_option.clear()
	_fixture_visual_option.add_item("— нет —")
	_fixture_visual_option.set_item_metadata(0, "")
	for obj in _editor.blueprint.objects:
		_fixture_visual_option.add_item(obj.id)
		_fixture_visual_option.set_item_metadata(_fixture_visual_option.item_count - 1, obj.id)
	for i in _fixture_visual_option.item_count:
		if String(_fixture_visual_option.get_item_metadata(i)) == fixture.visual_object_id:
			_fixture_visual_option.select(i)
			break
	# Zone dropdown — populate from the blueprint's owning areas.
	_fixture_zone_option.clear()
	_fixture_zone_option.add_item("— здание —")
	_fixture_zone_option.set_item_metadata(0, &"")
	for area in _editor.blueprint.areas:
		if not area.owns_content():
			continue
		_fixture_zone_option.add_item(area.display_name())
		_fixture_zone_option.set_item_metadata(_fixture_zone_option.item_count - 1, area.id)
	for i in _fixture_zone_option.item_count:
		if _fixture_zone_option.get_item_metadata(i) == fixture.owner_zone_id:
			_fixture_zone_option.select(i)
			break
	# Fire source defaults.
	var is_fire := fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE)
	_fixture_fire_defaults_lbl.visible = is_fire
	_fixture_fire_grid.visible = is_fire
	if is_fire:
		var defaults := FireSourceDefaultsScript.from_dict(fixture.runtime_defaults)
		_fixture_lit_check.button_pressed = defaults.lit
		_fixture_fuel_spin.value = defaults.fuel
		_fixture_cap_fuel_spin.value = defaults.fuel_capacity
	_syncing_ui = false


func add_fixture() -> void:
	var fixture := FixtureDefinitionScript.new()
	var next_index := 1
	var existing_ids: Array = _editor.blueprint.fixtures.map(func(f): return String(f.id))
	while "fixture_%d" % next_index in existing_ids:
		next_index += 1
	fixture.id = StringName("fixture_%d" % next_index)
	fixture.capabilities = [FixtureDefinitionScript.CAP_FIRE_SOURCE]
	fixture.runtime_defaults = {"lit": true, "fuel": 4, "fuel_capacity": 10}
	_editor.blueprint.fixtures.append(fixture)
	_selected_fixture_index = _editor.blueprint.fixtures.size() - 1
	_editor.mark_dirty()
	_refresh_fixture_list()
	_editor.set_status("Fixture создан: %s" % String(fixture.id))


func delete_fixture() -> void:
	if _selected_fixture_index < 0 or _selected_fixture_index >= _editor.blueprint.fixtures.size():
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	# Check if deleting this fixture would violate zone requirements.
	var warning := _fixture_deletion_warning(fixture)
	if not warning.is_empty():
		_editor.set_status("ВНИМАНИЕ: %s" % warning)
	_editor.blueprint.fixtures.remove_at(_selected_fixture_index)
	_selected_fixture_index = mini(_selected_fixture_index, _editor.blueprint.fixtures.size() - 1)
	_editor.mark_dirty()
	_refresh_fixture_list()
	if warning.is_empty():
		_editor.set_status("Fixture удалён.")
	else:
		_editor.set_status("Fixture удалён. ВНИМАНИЕ: %s" % warning)


## Returns a warning message if removing the fixture would leave a zone
## without a required capability. Empty string if no violation.
func _fixture_deletion_warning(fixture: FixtureDefinitionScript) -> String:
	# Check only zones the fixture is relevant to: building-wide fixtures
	# affect all zones, zone-specific ones only their own.
	var areas_to_check: Array[ZoneAreaRecord] = []
	for area in _editor.blueprint.areas:
		if fixture.owner_zone_id == &"" or area.id == fixture.owner_zone_id:
			areas_to_check.append(area)
	for area in areas_to_check:
		for cap in ZoneFunctionCatalog.required_capabilities(area.function):
			if not cap in fixture.capabilities:
				continue
			if not _zone_has_capability(area.id, cap, fixture):
				return "Зона «%s» останется без «%s»" % [area.display_name(), cap]
	return ""


## Returns true if any fixture (other than `exclude`) provides `cap` to the
## given zone (either zone-specific or building-wide).
func _zone_has_capability(zone_id: StringName, cap: StringName, exclude: FixtureDefinitionScript) -> bool:
	for f in _editor.blueprint.fixtures:
		if f == exclude:
			continue
		if f.owner_zone_id == zone_id or f.owner_zone_id == &"":
			if cap in f.capabilities:
				return true
	return false


func _on_fixture_list_selected(index: int) -> void:
	if _syncing_ui:
		return
	_selected_fixture_index = index
	_refresh_fixture_inspector()


func _on_fixture_capability_selected(index: int) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	var cap: StringName = _fixture_cap_option.get_item_metadata(index)
	# Replace capabilities with the single selected one (phase 2A: one cap per fixture).
	if fixture.capabilities == [cap]:
		return
	fixture.capabilities = [cap]
	_editor.mark_dirty()
	_refresh_fixture_inspector()


func _on_fixture_visual_selected(index: int) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	var visual_id := String(_fixture_visual_option.get_item_metadata(index))
	if fixture.visual_object_id == visual_id:
		return
	# A visual has one primary fixture. Reject ambiguity before saving.
	for other: FixtureDefinitionScript in _editor.blueprint.fixtures:
		if other != fixture and other.visual_object_id == visual_id and not visual_id.is_empty():
			_editor.set_status("Этот визуальный объект уже связан с fixture «%s»." % String(other.id))
			_refresh_fixture_inspector()
			return
	fixture.visual_object_id = visual_id
	_editor.mark_dirty()


func _on_fixture_zone_selected(index: int) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	var zone_id: StringName = _fixture_zone_option.get_item_metadata(index)
	if fixture.owner_zone_id == zone_id:
		return
	fixture.owner_zone_id = zone_id
	_editor.mark_dirty()


func _on_fixture_fire_param_changed(_value: Variant) -> void:
	if _syncing_ui or _selected_fixture_index < 0:
		return
	var fixture: FixtureDefinitionScript = _editor.blueprint.fixtures[_selected_fixture_index]
	if not fixture.has_capability(FixtureDefinitionScript.CAP_FIRE_SOURCE):
		return
	var defaults := {
		"lit": _fixture_lit_check.button_pressed,
		"fuel": int(_fixture_fuel_spin.value),
		"fuel_capacity": int(_fixture_cap_fuel_spin.value),
	}
	if fixture.runtime_defaults == defaults:
		return
	fixture.runtime_defaults = defaults
	_editor.mark_dirty()


func refresh_fixture_ui() -> void:
	_refresh_fixture_list()


## Clears visual_object_id references to a deleted fill object on all fixtures.
## Called by BuildingFillModeController._erase_object before the object is removed.
func clear_visual_references(object_id: String) -> void:
	for fixture: FixtureDefinitionScript in _editor.blueprint.fixtures:
		if fixture.visual_object_id == object_id:
			fixture.visual_object_id = ""
