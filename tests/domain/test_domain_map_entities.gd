class_name TestDomainMapEntities
extends RefCounted

## The authored entity crosses map data into session runtime without pulling in
## the editor or bootstrap controller.

static func run_all() -> void:
	_test_runtime_resolves_authored_differences()
	_test_runtime_offsets_entity_from_terrain()
	_test_presenter_applies_state_variant()
	_test_validator_rejects_structural_entity_errors()
	print("    [PASS] Map Entity Runtime Tests")


static func _document() -> MapDocument:
	var document := MapDocument.create(&"entities", "Сущности", 32)
	var entity := MapEntityRecord.new()
	entity.id = &"camp_1"
	entity.archetype_id = &"core:campfire"
	entity.position = Vector3(1.5, 0.0, 1.5)
	entity.initial_state = &"embers"
	entity.props = {&"fuel_units": 5}
	document.entities.entities.append(entity)
	return document


static func _test_runtime_resolves_authored_differences() -> void:
	EntityArchetypeCatalog.reload()
	var runtime := MapEntityRuntime.new()
	runtime.load_map(_document())
	var entity := runtime.by_id(&"camp_1")
	assert(entity != null)
	assert(entity.state == &"embers")
	assert(entity.props[&"fuel_units"] == 5)
	assert(entity.props[&"relights"] == true, "runtime overlays authored differences on archetype defaults")


static func _test_runtime_offsets_entity_from_terrain() -> void:
	EntityArchetypeCatalog.reload()
	var document := _document()
	document.terrain.set_height(Vector2i(1, 1), 4)
	document.entities.entities[0].position.y = 0.25
	var runtime := MapEntityRuntime.new()
	runtime.load_map(document, document.terrain)
	var entity := runtime.by_id(&"camp_1")
	assert(entity != null)
	assert(is_equal_approx(entity.position.y, 2.25), "entity Y is terrain height plus authored offset")


static func _test_validator_rejects_structural_entity_errors() -> void:
	var document := _document()
	var duplicate := MapEntityRecord.from_dict(document.entities.entities[0].to_dict())
	duplicate.position = Vector3(2.5, 0.0, 2.5)
	document.entities.entities.append(duplicate)
	var errors := MapValidator.validate(document, document.terrain, document.water, null)
	assert(errors.any(func(message: String) -> bool: return message.contains("дубликат")))
	document.entities.entities.pop_back()
	document.entities.entities[0].initial_state = &"not_a_state"
	errors = MapValidator.validate(document, document.terrain, document.water, null)
	assert(errors.any(func(message: String) -> bool: return message.contains("неизвестное состояние")))


static func _test_presenter_applies_state_variant() -> void:
	var runtime := MapEntityRuntime.new()
	runtime.load_map(_document())
	var territory := TerritoryBase.new()
	var presenter := MapEntityPresenter.new()
	presenter.present(runtime, territory)
	var view := presenter.view_for(&"camp_1")
	assert(view != null and view.get_meta("map_entity_state") == &"embers")
	var fire := view.get_node_or_null("Fire") as Node3D
	assert(fire != null and fire.visible, "embers keeps a reduced but visible flame variant")
	var light := view.get_node_or_null("Light") as OmniLight3D
	assert(light != null and is_equal_approx(light.light_energy, 0.6))
	presenter.clear()
	presenter.free()
	territory.free()
