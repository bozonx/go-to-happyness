class_name AmbientSpawner
extends Node3D

const HarvestSourceRecord = preload("res://game/features/production/domain/harvest_source_record.gd")
const ForageSourceRecord = preload("res://game/features/production/domain/forage_source_record.gd")
const RabbitSourceRecord = preload("res://game/features/production/domain/rabbit_source_record.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")
const WorldResourceStateScript = preload("res://game/features/world/domain/world_resource_state.gd")

## Компоненты, сущности которых строит этот спавнер, а не общий презентер
## (`WorldSession.claimed_entity_components`). Список объявлен здесь, потому что
## здесь же он и исполняется: пока «что пропускает презентер» и «что забирает
## спавнер» были двумя разными словами в двух файлах, архетип с одним только
## `wander` получал два тела — живое и неподвижную копию рядом.
const CLAIMED_COMPONENTS: Array[StringName] = [&"settlement_natural", &"wander"]

var simulation: Node
var map_document: MapDocument = null
## The entrance this session began at. Entities bound to another one are not
## created (`map_start.md` §3.2): a player who came in from the south must not
## find the cart the author put at the north gate.
var start_option: StringName = &""

class NaturalEntry:
	extends RefCounted
	var position := Vector3.ZERO
	var props: Dictionary = {}
	## Asset the archetype draws itself with. Two archetypes may share one gameplay
	## kind and differ only here — that is how a spruce is a tree.
	var asset_id: StringName = &""
	var appearance: Dictionary = {}
	## Повадка, если архетип объявил компонент `wander`. Пусто — существо не
	## бродит (или это вообще не существо).
	var habit: WanderHabit = null
	## Значение `settlement_natural.kind`, если компонент есть.
	var kind: StringName = &""
	## Запись карты, из которой выросла эта нода. Пусто — объект восстановлен из
	## сейва и записи карты за ним не стоит.
	var entity_id: StringName = &""
	var archetype: EntityArchetype = null


## Ноды, построенные из записей карты, по id записи. Нужны ровно для одного:
## смена состояния сущности (сезон, §6.1) обязана доезжать и до них. Презентер
## ведёт такой же список для сущностей, которых этот спавнер НЕ забрал.
var _views: Dictionary = {}
var _runtime: MapEntityRuntime = null


func setup(p_simulation: Node, map_document: MapDocument = null, p_start_option: StringName = &"") -> void:
	simulation = p_simulation
	self.map_document = map_document
	start_option = p_start_option


## Подписывается на runtime карты, чтобы построенные здесь ноды меняли вид
## вместе с записью. Без этого сезонный перевод менял состояние в данных и
## ничего не менял на экране — ровно у той половины карты, которую строит этот
## спавнер.
func observe(runtime: MapEntityRuntime) -> void:
	_runtime = runtime
	if runtime == null:
		return
	if not runtime.entity_changed.is_connected(_on_entity_changed):
		runtime.entity_changed.connect(_on_entity_changed)


func _on_entity_changed(entity_id: StringName, change: StringName) -> void:
	if change != &"state":
		return
	_apply_entity_state(entity_id, _views.get(entity_id, null))


## Нода, построенная из записи карты, запоминается под её id и сразу получает
## состояние, до которого запись уже дошла: карта, запущенная в январе, обязана
## быть зимней с первого кадра, а не с первой смены сезона.
##
## Восстановленные из сейва объекты записи карты не имеют и сюда не попадают —
## их состояние принадлежит механике сбора, а не календарю.
func _remember(entry: NaturalEntry, node: Node3D) -> void:
	if entry.entity_id == &"" or node == null:
		return
	_views[entry.entity_id] = node
	node.set_meta("map_entity_id", entry.entity_id)
	_apply_entity_state(entry.entity_id, node)


func _apply_entity_state(entity_id: StringName, view: Node3D) -> void:
	if _runtime == null or not is_instance_valid(view):
		return
	var entity := _runtime.by_id(entity_id)
	if entity == null:
		return
	view.set_meta("map_entity_state", entity.state)
	EntityStateAppearance.apply(
		view, entity.archetype, entity.state,
		WorldAssetCatalog.get_asset(entity.archetype.asset_id), entity.appearance)


func _entities_of_kind(kind: StringName) -> Array[NaturalEntry]:
	return _entities_where(func(archetype: EntityArchetype) -> bool:
		return archetype.has_component(&"settlement_natural") \
			and StringName(archetype.component_data(&"settlement_natural").get("kind", "")) == kind)


## Всё живое на доске: архетипы, объявившие повадку. Кролик попадает сюда же, а
## не отдельной веткой, — он «бродячее существо, которое вдобавок можно поймать»,
## а не отдельный вид сущности.
func _wandering_entities() -> Array[NaturalEntry]:
	return _entities_where(func(archetype: EntityArchetype) -> bool:
		return archetype.has_component(&"wander"))


func _entities_where(predicate: Callable) -> Array[NaturalEntry]:
	var result: Array[NaturalEntry] = []
	if map_document == null:
		return result
	for placed: MapEntityRecord in map_document.entities.entities:
		if not placed.belongs_to_start(start_option):
			continue
		var archetype := EntityArchetypeCatalog.get_archetype(placed.archetype_id)
		if archetype == null or not bool(predicate.call(archetype)):
			continue
		var entry := NaturalEntry.new()
		entry.position = placed.position
		entry.position.y = simulation.terrain_height_at(entry.position.x, entry.position.z, entry.position.y) + placed.position.y
		entry.props = archetype.resolved_properties(placed.props)
		entry.asset_id = archetype.asset_id
		entry.appearance = placed.appearance.duplicate(true)
		if archetype.has_component(&"wander"):
			entry.habit = WanderHabit.from_component(archetype.component_data(&"wander"))
		if archetype.has_component(&"settlement_natural"):
			entry.kind = StringName(archetype.component_data(&"settlement_natural").get("kind", ""))
		entry.entity_id = placed.id
		entry.archetype = archetype
		result.append(entry)
	return result


## Scene of a catalog asset, or null when the pack that owns it is not installed.
## A missing asset must not take the session down with it (`map_fill_mode.md` §11):
## the entity is skipped and the rest of the map still loads.
func _scene_of(asset_id: StringName) -> PackedScene:
	var asset := WorldAssetCatalog.get_asset(asset_id)
	if asset == null or not ResourceLoader.exists(asset.scene_path):
		push_warning("AmbientSpawner: ассет «%s» не найден в каталоге" % asset_id)
		return null
	return load(asset.scene_path) as PackedScene


## Authored appearance wins; whatever the author left alone is drawn from the
## world seed, so a hand-placed forest still is not a row of identical clones. The
## record stays the single owner of what an object looks like — this only fills
## the keys it never spoke about.
##
## The draw is seeded by the cell, not taken from the shared world RNG, and that
## is the whole point: a reloaded save recreates its bushes in a different order
## and would otherwise recolour the meadow every time the player loads.
func _apply_appearance(node: Node3D, entry: NaturalEntry) -> void:
	var asset := WorldAssetCatalog.get_asset(entry.asset_id)
	if asset == null or not node.has_method("apply_decor_properties"):
		return
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([entry.asset_id, cell.x, cell.y, simulation.random.seed])
	var appearance := asset.default_appearance()
	appearance.merge(asset.random_appearance(rng), true)
	appearance.merge(entry.appearance, true)
	node.call("apply_decor_properties", appearance)


func create_forest() -> void:
	for entry in _entities_of_kind(&"tree"):
		var tree_position: Vector3 = entry.position
		var cell: Vector2i = simulation.cell_from_position(tree_position)
		simulation.tree_cells[cell] = true
		simulation.tree_positions.append(tree_position)
		_create_tree(entry, false)
	for entry in _entities_of_kind(&"grass_source"):
		_create_grass_source_at(entry, int(entry.props.get(&"amount", 3)))
	for entry in _entities_of_kind(&"bush"):
		_create_bush_at(entry, int(entry.props.get(&"branches", 3)))
	for entry in _entities_of_kind(&"forage_source"):
		_create_forage_source_at(entry)
	simulation.world_navigation_controller.refresh_navigation_grid()
	# Fireflies are no longer spawned here: they are authored as `core:fireflies`
	# map entities, rendered by MapEntityPresenter and driven by the ambient-effect
	# group the weather controller publishes to.


func _create_tree(entry: NaturalEntry, refresh_navigation := true) -> void:
	var scene := _scene_of(entry.asset_id)
	if scene == null:
		return
	var tree: Node3D = scene.instantiate()
	tree.position = entry.position
	var initial_wood := int(entry.props.get(&"wood", simulation.random.randi_range(4, 7)))
	var initial_branches := int(entry.props.get(&"branches", simulation.random.randi_range(5, 9)))

	var cell: Vector2i = simulation.cell_from_position(entry.position)
	var tree_state: Variant = simulation.world_resource_state.create_tree(cell, initial_wood, initial_branches)
	_sync_tree_visual_state(tree, tree_state)
	simulation.tree_nodes[cell] = tree
	simulation.world_navigation_controller.add_landscape_object(tree)

	# Add the tree interaction selector group so first-person raycast can find it.
	var interaction_selector := tree.get_node_or_null("TreeInteractionSelector") as Area3D
	if interaction_selector != null:
		interaction_selector.add_to_group("tree_selector")

	_apply_appearance(tree, entry)
	_remember(entry, tree)

	simulation.terrain_blocked_cells[cell] = true
	if refresh_navigation:
		simulation.world_navigation_controller.refresh_navigation_grid()


func _create_grass_source_at(entry: NaturalEntry, amount: int) -> void:
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	if not simulation.is_board_cell(cell) or simulation.grass_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node := _instantiate_source(entry, "grass_selector", Vector3(1.2, 0.9, 1.2), Vector3.UP * 0.4)
	if node == null:
		return
	simulation.grass_sources[cell] = HarvestSourceRecord.new(node, amount, amount)


func _create_bush_at(entry: NaturalEntry, branches: int) -> void:
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	if not simulation.is_board_cell(cell) or simulation.bush_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node := _instantiate_source(entry, "bush_selector", Vector3(1.2, 1.0, 1.2), Vector3.UP * 0.45)
	if node == null:
		return
	simulation.bush_sources[cell] = HarvestSourceRecord.new(node, branches, branches)


func _create_forage_source_at(entry: NaturalEntry) -> void:
	var cell: Vector2i = simulation.cell_from_position(entry.position)
	if not simulation.is_board_cell(cell) or simulation.forage_sources.has(cell) or simulation.tree_cells.has(cell):
		return
	var node := _instantiate_source(entry, "forage_selector", Vector3(0.7, 0.6, 0.7), Vector3.UP * 0.3)
	if node == null:
		return
	simulation.forage_sources[cell] = ForageSourceRecord.new(node)


## Shared body of "put a small harvestable plant on the board": instantiate from
## the catalog, give it its click target, hand it to the landscape.
func _instantiate_source(
	entry: NaturalEntry,
	selector_group: String,
	selector_size: Vector3,
	selector_offset: Vector3
) -> Node3D:
	var scene := _scene_of(entry.asset_id)
	if scene == null:
		return null
	var node: Node3D = scene.instantiate()
	node.position = entry.position + Vector3.UP * 0.05
	simulation.building_visuals.add_selector_to_node(node, selector_group, selector_size, selector_offset)
	simulation.world_navigation_controller.add_landscape_object(node)
	_apply_appearance(node, entry)
	_remember(entry, node)
	return node


func setup_entrance_sign_node(entrance_stone: Node3D) -> void:
	if not is_instance_valid(entrance_stone):
		return
	var entrance_sign_light := entrance_stone.get_node_or_null("EntranceSignLight") as OmniLight3D
	if entrance_sign_light != null and not simulation.entrance_lights.has(entrance_sign_light):
		simulation.entrance_lights.append(entrance_sign_light)


func spawn_trash_piles() -> void:
	for entry in _entities_of_kind(&"starter_loot"):
		var cell: Vector2i = simulation.cell_from_position(entry.position)
		if not simulation.is_board_cell(cell) or simulation.terrain_blocked_cells.has(cell):
			continue
		var pile: Node3D = simulation.resource_pile_service.create_resource_pile(entry.position, _loot_resources(entry.props)) as Node3D
		# These are authored world loot, unlike piles dropped by citizens or
		# logistics. Keep their visuals under the territory while the logistics
		# service continues to own their resource record.
		if pile != null:
			pile.set_meta("landscape_owned", true)
			simulation.world_navigation_controller.add_landscape_object(pile)


func _loot_resources(loot: Dictionary) -> Dictionary:
	var resources: Dictionary = {}
	for field in [{"name": &"grass", "resource": ResourceIds.GRASS}, {"name": &"branches", "resource": ResourceIds.BRANCHES}]:
		var amount := int(loot.get(field.name, 0))
		if amount > 0:
			resources[field.resource] = amount
	return resources


## Всё, что бродит по карте. Один проход на всех: кролик отличается от оленя
## архетипом, а не веткой кода здесь. Единственная особая строка — учёт в
## `rabbit_sources`, и она особая честно: охота пока умеет ровно один вид.
func spawn_wildlife() -> void:
	for entry in _wandering_entities():
		if entry.kind == &"rabbit" and simulation.rabbit_sources.size() >= simulation.RABBIT_MAX_COUNT:
			continue
		_create_creature(entry)


func _create_creature(entry: NaturalEntry) -> Node3D:
	var scene := _scene_of(entry.asset_id)
	if scene == null:
		return null
	var node: Node3D = scene.instantiate()
	# Без подъёма над точкой: высоту существу выставляет служба на первом же шаге
	# (`AmbientLifeService.GROUND_SNAP`). Прибавлять её ещё и здесь значило бы,
	# что каждый цикл сохранения приподнимает зверя над землёй.
	node.position = entry.position
	if entry.kind == &"rabbit":
		simulation.building_visuals.add_selector_to_node(
			node, "rabbit_selector", Vector3(0.5, 0.5, 0.5), Vector3.UP * 0.25)
		simulation.rabbit_sources[simulation.cell_from_position(entry.position)] = \
			RabbitSourceRecord.new(node)
	simulation.world_navigation_controller.add_landscape_object(node)
	_apply_appearance(node, entry)
	_remember(entry, node)
	if entry.habit != null and simulation.ambient_life_service != null:
		# Стая — это те, у кого совпадает вид: олени держатся оленей.
		simulation.ambient_life_service.register(node, entry.habit, entry.kind)
	return node


## Wild food no longer respawns: a harvested bush or a caught rabbit is gone for
## the rest of the session, which keeps the map finite and avoids fabricating new
## positions. Roaming is not done here any more — `AmbientLifeService` moves every
## wandering creature, so a second animal is an archetype rather than a second
## copy of this loop.


func export_resource_state() -> Dictionary:
	var state := WorldResourceStateScript.new()
	state.capture(
		simulation.grass_sources,
		simulation.forage_sources,
		simulation.rabbit_sources,
		simulation.bush_sources
	)
	return state.to_save_dict()


func restore_resource_state(data: Dictionary) -> void:
	if data.is_empty():
		return # Older saves retain the freshly generated natural resources.
	var state := WorldResourceStateScript.new()
	state.load_from_save_dict(data)
	_clear_natural_source_nodes()
	for entry: Dictionary in state.grass_sources:
		var cell := WorldResourceStateScript._dict_to_cell(entry.get("cell", {}))
		_create_grass_source(cell, int(entry.get("remaining", 0)), int(entry.get("initial", 0)))
	for entry: Dictionary in state.bush_sources:
		var bush_cell := WorldResourceStateScript._dict_to_cell(entry.get("cell", {}))
		_create_bush(bush_cell, int(entry.get("remaining", 0)), int(entry.get("initial", 0)))
	for cell in state.forage_cells:
		_create_forage_source(cell)
	for entry: Dictionary in state.rabbits:
		_create_rabbit_source(WorldResourceStateScript._dict_to_vector(entry.get("position", {})))


## Сносит только то, что сейв восстановит заново, — четыре словаря источников.
##
## Снимается с учёта ровно столько же. Раньше здесь стоял `clear()` всей службы:
## он снимал и оленя с волком, которых потом никто не регистрировал обратно, —
## их ноды в эти словари не входят, поэтому и не пересоздаются. Зверь оставался
## стоять там, где его застала загрузка, и больше не двигался никогда.
func _clear_natural_source_nodes() -> void:
	for sources: Dictionary in [
		simulation.grass_sources,
		simulation.bush_sources,
		simulation.forage_sources,
		simulation.rabbit_sources,
	]:
		for source in sources.values():
			if is_instance_valid(source.node):
				if simulation.ambient_life_service != null:
					simulation.ambient_life_service.forget(source.node)
				source.node.queue_free()
		sources.clear()


func _create_grass_source(cell: Vector2i, remaining: int, initial: int) -> void:
	var node := _instantiate_source(
		_restored_entry(&"grass_source", _cell_position(cell)),
		"grass_selector", Vector3(1.2, 0.9, 1.2), Vector3.UP * 0.4
	)
	if node != null:
		simulation.grass_sources[cell] = HarvestSourceRecord.new(node, remaining, initial)


func _create_bush(cell: Vector2i, remaining: int, initial: int) -> void:
	var node := _instantiate_source(
		_restored_entry(&"bush", _cell_position(cell)),
		"bush_selector", Vector3(1.2, 1.0, 1.2), Vector3.UP * 0.45
	)
	if node != null:
		simulation.bush_sources[cell] = HarvestSourceRecord.new(node, remaining, initial)


func _create_forage_source(cell: Vector2i) -> void:
	var node := _instantiate_source(
		_restored_entry(&"forage_source", _cell_position(cell)),
		"forage_selector", Vector3(0.7, 0.6, 0.7), Vector3.UP * 0.3
	)
	if node != null:
		simulation.forage_sources[cell] = ForageSourceRecord.new(node)


## Восстановление из сейва. Курс существа не сохраняется и не нужен: он меняется
## каждую секунду, и через мгновение после загрузки от сохранённого не осталось
## бы ничего — служба выдаёт новый при постановке на учёт.
func _create_rabbit_source(position: Vector3) -> void:
	_create_creature(_restored_entry(&"rabbit", position))


## A save stores where a source stands and how much is left in it, not what it
## looked like. Rebuilding the entry from the engine default and letting the
## cell-seeded draw fill the rest is what makes the restored meadow match the one
## the player saved.
##
## Вид ищется в каталоге архетипов, а не собирается здесь из констант: повадка
## кролика объявлена в `rabbit.gdarchetype.json`, и второй её экземпляр в этом
## файле означал бы, что перенастроенный архетип не доезжает до загруженной игры.
## Пак без архетипа не роняет загрузку — остаётся объект без повадки.
func _restored_entry(kind: StringName, position: Vector3) -> NaturalEntry:
	var entry := NaturalEntry.new()
	entry.asset_id = kind
	entry.position = position
	var archetype := _archetype_of_kind(kind)
	if archetype != null:
		entry.asset_id = archetype.asset_id
		entry.kind = kind
		if archetype.has_component(&"wander"):
			entry.habit = WanderHabit.from_component(archetype.component_data(&"wander"))
	return entry


## Архетип, объявивший этот вид. Восстановление берёт ассет и повадку оттуда же,
## откуда их берёт первая расстановка (`_entities_of_kind`).
static func _archetype_of_kind(kind: StringName) -> EntityArchetype:
	for archetype: EntityArchetype in EntityArchetypeCatalog.all():
		if not archetype.has_component(&"settlement_natural"):
			continue
		if StringName(archetype.component_data(&"settlement_natural").get("kind", "")) == kind:
			return archetype
	return null


func _cell_position(cell: Vector2i) -> Vector3:
	if simulation.nav_grid != null:
		return simulation.nav_grid.cell_center(cell)
	return Vector3((cell.x + 0.5) * simulation.CELL_SIZE, 0.0, (cell.y + 0.5) * simulation.CELL_SIZE)


func _sync_tree_visual_state(tree: Node3D, state: Variant) -> void:
	# Compatibility projection for presentation code that has not yet moved to
	# WorldResourceState. Gameplay writes go through the state record.
	tree.set_meta("initial_wood", state.initial_wood)
	tree.set_meta("remaining_wood", state.remaining_wood)
	tree.set_meta("initial_branches", state.initial_branches)
	tree.set_meta("remaining_branches", state.remaining_branches)
	tree.set_meta("hand_branches", state.hand_branches)
	tree.set_meta("branch_exhausted", state.branch_exhausted)
	tree.set_meta("felled", state.felled)
