class_name ScatterWorld
extends Node3D

## Рисует массовое наполнение чанковыми `MultiMesh`
## (`map_fill_mode.md` §9.4).
##
## Это единственный способ держать десятки тысяч объектов. Инстансированная
## сцена стоит двадцати нод и уникального материала на объект: три тысячи
## деревьев — шестьдесят тысяч нод и три тысячи материалов, то есть отсутствие
## батчинга при полном отсутствии выгоды. Здесь один буфер на пару «чанк ×
## архетип», нарезка та же 16×16, которой уже нарезан рельеф.
##
## Чанк — не украшение, а условие: перестроить один чанк после мазка кисти стоит
## своих записей, а не всей карты, и `VisualInstance3D` целого леса не отсекается
## камерой никогда.
##
## Игровой host может забрать архетипы по компонентам: они исключаются из
## MultiMesh и получают живые ноды у adapter-а. Для остальных scene-owned
## коллизий эта проекция поднимает невидимые collision proxy, сохраняя визуал
## батчированным. Произвольной ленивой activation/LOD-системы здесь нет.

## Тень от травинки стоит столько же, сколько тень от дома, поэтому мелочь её не
## отбрасывает. Порог в метрах по наибольшему габариту ассета.
const SHADOW_MIN_SIZE := 1.2

var _layer: MapScatterLayer = null
var _terrain: TerrainGrid = null
var _water: WaterGrid = null
var _excluded_components: Array[StringName] = []
var _chunks: Dictionary = {}
var _collision_chunks: Dictionary = {}
var _build_scene_collisions := false
var _terrain_service: TerrainService = null
var _water_service: WaterService = null


## Полная перестройка. Вызывается при загрузке карты и после генерации — то есть
## тогда, когда изменилось всё.
func configure(
	layer: MapScatterLayer,
	terrain: TerrainGrid,
	water: WaterGrid = null,
	excluded_components: Array[StringName] = [],
	build_scene_collisions := false,
) -> void:
	_layer = layer
	_terrain = terrain
	_water = water
	_excluded_components = excluded_components.duplicate()
	_build_scene_collisions = build_scene_collisions
	rebuild_all()


func bind_services(terrain_service: TerrainService, water_service: WaterService) -> void:
	_unbind_services()
	_terrain_service = terrain_service
	_water_service = water_service
	if _terrain_service != null:
		_terrain_service.edit_committed.connect(_on_terrain_edited)
	if _water_service != null:
		_water_service.edit_committed.connect(_on_water_edited)


func _exit_tree() -> void:
	_unbind_services()


func _unbind_services() -> void:
	if _terrain_service != null \
			and _terrain_service.edit_committed.is_connected(_on_terrain_edited):
		_terrain_service.edit_committed.disconnect(_on_terrain_edited)
	if _water_service != null \
			and _water_service.edit_committed.is_connected(_on_water_edited):
		_water_service.edit_committed.disconnect(_on_water_edited)
	_terrain_service = null
	_water_service = null


func _on_terrain_edited(delta: TerrainDelta) -> void:
	if delta == null or not delta.changes_geometry():
		return
	var affected: Array[Vector2i] = []
	for cell: Vector2i in delta.cells:
		# A record samples the neighboring height for normal alignment.
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var chunk := _terrain.chunk_of(cell + Vector2i(dx, dz))
				if chunk not in affected:
					affected.append(chunk)
	refresh_chunks(affected)


func _on_water_edited(delta: WaterDelta) -> void:
	if delta == null:
		return
	var affected: Array[Vector2i] = []
	for cell: Vector2i in delta.cells:
		var chunk := _terrain.chunk_of(cell)
		if chunk not in affected:
			affected.append(chunk)
	refresh_chunks(affected)


func rebuild_all() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_chunks.clear()
	_collision_chunks.clear()
	if _layer == null or _terrain == null or _layer.is_empty():
		return
	var by_chunk: Dictionary = {}
	for index in _layer.records.size():
		var record := _layer.records[index]
		if record.is_empty():
			continue
		var chunk := _terrain.chunk_of(record.cell)
		var bucket: Array = by_chunk.get(chunk, [])
		bucket.append(index)
		by_chunk[chunk] = bucket
	for chunk: Vector2i in by_chunk:
		_build_chunk(chunk, by_chunk[chunk])


## Перестраивает только чанки, которых коснулась правка. Ради этого нарезка и
## существует: мазок кисти по одной поляне не должен стоить всей карты.
func refresh_chunks(chunks: Array) -> void:
	if _layer == null or _terrain == null:
		return
	for chunk: Vector2i in chunks:
		_clear_chunk(chunk)
		var indices: Array = []
		for index in _layer.records.size():
			var record := _layer.records[index]
			if not record.is_empty() and _terrain.chunk_of(record.cell) == chunk:
				indices.append(index)
		if not indices.is_empty():
			_build_chunk(chunk, indices)


func chunk_count() -> int:
	return _chunks.size()


## Сколько экземпляров нарисовано. Для тестов и для отладочной панели: «лес есть
## в данных» и «лес виден» — разные утверждения, и второе проверяется этим.
func instance_count() -> int:
	var total := 0
	for chunk: Vector2i in _chunks:
		for instance: MultiMeshInstance3D in _chunks[chunk]:
			total += instance.multimesh.instance_count
	return total


func _clear_chunk(chunk: Vector2i) -> void:
	if _chunks.has(chunk):
		for instance: MultiMeshInstance3D in _chunks[chunk]:
			if is_instance_valid(instance):
				remove_child(instance)
				instance.queue_free()
		_chunks.erase(chunk)
	if _collision_chunks.has(chunk):
		for proxy: Node3D in _collision_chunks[chunk]:
			if is_instance_valid(proxy):
				remove_child(proxy)
				proxy.queue_free()
		_collision_chunks.erase(chunk)


func _build_chunk(chunk: Vector2i, record_indices: Array) -> void:
	var by_archetype: Dictionary = {}
	for index: int in record_indices:
		var archetype_id := _layer.archetype_of(_layer.records[index])
		var bucket: Array = by_archetype.get(archetype_id, [])
		bucket.append(index)
		by_archetype[archetype_id] = bucket

	var built: Array[MultiMeshInstance3D] = []
	for archetype_id: StringName in by_archetype:
		if _is_claimed(archetype_id):
			continue
		var instance := _build_bucket(archetype_id, by_archetype[archetype_id])
		if instance != null:
			instance.name = "Scatter_%d_%d_%s" % [chunk.x, chunk.y, String(archetype_id).replace(":", "_")]
			add_child(instance)
			built.append(instance)
	if not built.is_empty():
		_chunks[chunk] = built
	_build_collision_proxies(chunk, record_indices)


func _build_collision_proxies(chunk: Vector2i, record_indices: Array) -> void:
	if not _build_scene_collisions:
		return
	var proxies: Array[Node3D] = []
	for index: int in record_indices:
		var record := _layer.records[index]
		var archetype_id := _layer.archetype_of(record)
		if _is_claimed(archetype_id):
			continue
		var asset := EntityArchetypeCatalog.asset_of(archetype_id)
		if asset == null or asset.collision_policy != WorldAssetDef.COLLISION_SCENE \
				or not ResourceLoader.exists(asset.scene_path):
			continue
		var scene := load(asset.scene_path) as PackedScene
		var proxy := scene.instantiate() as Node3D if scene != null else null
		if proxy == null:
			continue
		proxy.name = "ScatterCollision_%d" % index
		proxy.transform = transform_of(record)
		proxy.visible = false
		proxy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(proxy)
		proxies.append(proxy)
	if not proxies.is_empty():
		_collision_chunks[chunk] = proxies


func _build_bucket(archetype_id: StringName, record_indices: Array) -> MultiMeshInstance3D:
	var asset := EntityArchetypeCatalog.asset_of(archetype_id)
	if asset == null:
		return null
	var baked := ScatterMeshBaker.bake(asset)
	if baked == null or baked.mesh == null:
		return null

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = baked.has_instance_colour()
	multimesh.mesh = baked.mesh
	multimesh.instance_count = record_indices.size()

	var slot := 0
	for index: int in record_indices:
		var record := _layer.records[index]
		multimesh.set_instance_transform(slot, transform_of(record))
		if multimesh.use_colors:
			multimesh.set_instance_color(slot, _colour_of(baked, record))
		slot += 1

	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	# Тень от травинки стоит столько же, сколько тень от дома. Мелочь её не
	# отбрасывает — и это единственная причина, по которой поляна из десяти тысяч
	# травинок вообще рисуется.
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if asset.size_m.y >= SHADOW_MIN_SIZE
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	return instance


func transform_of(record: MapScatterLayer.Record) -> Transform3D:
	var archetype_id := _layer.archetype_of(record)
	var asset := EntityArchetypeCatalog.asset_of(archetype_id)
	var policy := asset.placement_policy() if asset != null else null
	var centre := _terrain.cell_center(record.cell)
	var position := Vector3(
		centre.x + record.offset.x * _terrain.cell_size,
		0.0,
		centre.z + record.offset.y * _terrain.cell_size)
	# Высота — у рельефа, всегда. Объект, помнящий свою мировую Y, отрывается от
	# земли при первой же правке ландшафта (§9.3).
	position.y = _terrain.height_at(position)
	position.y += EntityPlacementProbe.surface_offset(
		policy, _terrain, _water, record.cell, position)
	var basis := EntityPlacementProbe.aligned_basis(
		_terrain, position, record.yaw_degrees, policy, record.scale)
	return Transform3D(basis, position)


func _is_claimed(archetype_id: StringName) -> bool:
	if _excluded_components.is_empty():
		return false
	var archetype := EntityArchetypeCatalog.get_archetype(archetype_id)
	if archetype == null:
		return false
	for component: StringName in _excluded_components:
		if archetype.has_component(component):
			return true
	return false


## Цвет экземпляра — тот же разброс `vary`, что у одиночной постановки, посеянный
## байтом варианта записи. Одна и та же карта поэтому окрашена одинаково при
## каждой загрузке, а соседние деревья — по-разному.
static func _colour_of(baked: ScatterMeshBaker.Baked, record: MapScatterLayer.Record) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([record.cell.x, record.cell.y, record.variant])
	return WorldAssetDef.jittered_color(baked.instance_colour_base, baked.instance_colour_vary, rng)
