extends SceneTree

## Существо на карте имеет ровно одно тело (`map_fill_mode.md` §5).
##
## Кто строит сущность — вопрос с одним ответом, и этот тест держит его таким.
## Раньше ответов было два: общий презентер пропускал `settlement_natural`, а
## `AmbientSpawner` забирал `wander`. Архетип, объявивший только повадку, попадал
## под оба правила и получал два тела — живое от спавнера и неподвижную копию от
## презентера, — а какое из них «настоящий зверь», не говорил никто.
##
## Фикстура ставится паком в `user://`, а не добавляется в `core`: проверяется
## именно чужой архетип, про который движок ничего не знает заранее.

const GameRuntimeScene = preload("res://game/bootstrap/game_runtime.tscn")

const PACK_ROOT := "user://content/installed/gth.test_creature"
const PACK := {
	"format_version": 2,
	"id": "gth.test_creature",
	"name": "Creature fixture",
	"author_id": "tests",
	"author_name": "Tests",
	"version": "1.0.0",
	"revision": "fixture-1",
	"provides": {"styles": []},
	"requires": [],
}
const ARCHETYPE := {
	"version": 1,
	"id": "lone_wanderer",
	"name": "Одинокий бродяга",
	"asset": "lone_asset",
	"content_class": "actor",
	"category": "creatures",
	"components": {"wander": {"habit": "grazing"}},
}
const ASSET := {
	"id": "lone_asset",
	"name": "Wanderer asset",
	"scene": "res://game/features/content/presentation/assets/rabbit.tscn",
	"category": "creatures",
	"scope": "map",
	"size_m": [0.55, 0.45, 0.35],
	"collision": "scene",
	"placement": {"surface": ["ground"], "scatter": {"allowed": true}},
}
const ARCHETYPE_ID := &"gth.test_creature:lone_wanderer"
const ENTITY_ID := &"lone_wanderer_1"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_install_fixture()
	WorldAssetCatalog.refresh()
	EntityArchetypeCatalog.reload()
	assert(EntityArchetypeCatalog.get_archetype(ARCHETYPE_ID) != null,
		"фикстура архетипа не загрузилась")
	assert(EntityArchetypeCatalog.asset_of(ARCHETYPE_ID) != null,
		"pack asset не загрузился: %s" % [WorldAssetCatalog.load_errors])
	assert(EntityArchetypeCatalog.asset_of(ARCHETYPE_ID).id == &"gth.test_creature:lone_asset",
		"pack-owned asset обязан получить namespace пака")

	var definition := GameModuleRegistry.resolve_definition(&"core:settlement")
	var map := MapDocumentService.new().load_map(definition.default_map)
	assert(map != null)
	var entity := MapEntityRecord.new()
	entity.id = ENTITY_ID
	entity.archetype_id = ARCHETYPE_ID
	entity.position = Vector3(2.5, 0.0, 2.5)
	map.entities.entities.append(entity)
	var scattered := MapScatterLayer.Record.new()
	scattered.archetype_index = map.scatter.archetype_index_of(ARCHETYPE_ID)
	scattered.cell = Vector2i(-8, -8)
	scattered.offset = Vector2(0.2, -0.15)
	map.scatter.add(scattered)

	var launch_manager := root.get_node_or_null("GameLaunchManager")
	launch_manager.active_session = GameSessionConfig.create(definition, &"editor:preview", map)
	var runtime := GameRuntimeScene.instantiate() as GameRuntime
	root.add_child(runtime)
	for _frame in range(4):
		await physics_frame

	var simulation := runtime.session_content as SettlementGame
	assert(simulation != null)
	var setup: WorldSetup = simulation.world_setup
	assert(setup.map_entity_runtime.by_id(ENTITY_ID) != null,
		"запись должна существовать в runtime независимо от того, кто её рисует")
	# Тело ровно одно, и оно принадлежит спавнеру: презентер видит заявку хоста на
	# компонент `wander` и не строит вторую копию.
	assert(setup.map_entity_presenter.view_for(ENTITY_ID) == null,
		"презентер не должен строить вид для сущности, заявленной хостом")
	assert(_find_node_named(simulation, "MapEntity_%s" % ENTITY_ID) == null,
		"второго тела не должно быть нигде в дереве сцены")
	# И это тело живое: спавнер поставил его на учёт службе бродилок.
	assert(simulation.ambient_life_service.count() == _wandering_record_count(map),
		"каждое бродячее существо карты должно быть на учёте ровно один раз")

	runtime.stop_session()
	root.remove_child(runtime)
	runtime.free()
	await process_frame
	await physics_frame
	_uninstall_fixture()
	print("--- test_creature_single_body.gd PASSED ---")
	quit(0)


static func _wandering_record_count(map: MapDocument) -> int:
	var total := 0
	for placed: MapEntityRecord in map.entities.entities:
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype != null and archetype.has_component(&"wander"):
			total += 1
	for placed: MapScatterLayer.Record in map.scatter.records:
		if placed.is_empty():
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(map.scatter.archetype_of(placed))
		if archetype != null and archetype.has_component(&"wander"):
			total += 1
	return total


static func _find_node_named(root_node: Node, node_name: String) -> Node:
	if root_node.name == node_name:
		return root_node
	for child in root_node.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null


static func _install_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(PACK_ROOT.path_join("archetypes"))
	DirAccess.make_dir_recursive_absolute(PACK_ROOT.path_join("assets"))
	var manifest := FileAccess.open(PACK_ROOT.path_join("pack.json"), FileAccess.WRITE)
	manifest.store_string(JSON.stringify(PACK))
	manifest.close()
	var file := FileAccess.open(
		PACK_ROOT.path_join("archetypes/lone_wanderer.gdarchetype.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(ARCHETYPE))
	file.close()
	var asset_file := FileAccess.open(
		PACK_ROOT.path_join("assets/lone_asset.gdasset.json"), FileAccess.WRITE)
	asset_file.store_string(JSON.stringify(ASSET))
	asset_file.close()


static func _uninstall_fixture() -> void:
	DirAccess.remove_absolute(PACK_ROOT.path_join("archetypes/lone_wanderer.gdarchetype.json"))
	DirAccess.remove_absolute(PACK_ROOT.path_join("assets/lone_asset.gdasset.json"))
	DirAccess.remove_absolute(PACK_ROOT.path_join("archetypes"))
	DirAccess.remove_absolute(PACK_ROOT.path_join("assets"))
	DirAccess.remove_absolute(PACK_ROOT.path_join("pack.json"))
	DirAccess.remove_absolute(PACK_ROOT)
