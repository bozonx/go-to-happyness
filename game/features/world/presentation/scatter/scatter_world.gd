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
## **Ноды у объектов нет вовсе.** Ленивая нода из §9.4 — это следующий разговор:
## она нужна тому, с чем взаимодействуют, а безымянному дереву из слоя наполнения
## не нужна, пока никто не попросил его срубить. Механика, которой нода
## понадобится, поднимет запись в `entities[]` — там нода есть всегда.

## Тень от травинки стоит столько же, сколько тень от дома, поэтому мелочь её не
## отбрасывает. Порог в метрах по наибольшему габариту ассета.
const SHADOW_MIN_SIZE := 1.2

var _layer: MapScatterLayer = null
var _terrain: TerrainGrid = null
var _chunks: Dictionary = {}


## Полная перестройка. Вызывается при загрузке карты и после генерации — то есть
## тогда, когда изменилось всё.
func configure(layer: MapScatterLayer, terrain: TerrainGrid) -> void:
	_layer = layer
	_terrain = terrain
	rebuild_all()


func rebuild_all() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_chunks.clear()
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
	if not _chunks.has(chunk):
		return
	for instance: MultiMeshInstance3D in _chunks[chunk]:
		if is_instance_valid(instance):
			remove_child(instance)
			instance.queue_free()
	_chunks.erase(chunk)


func _build_chunk(chunk: Vector2i, record_indices: Array) -> void:
	var by_archetype: Dictionary = {}
	for index: int in record_indices:
		var archetype_id := _layer.archetype_of(_layer.records[index])
		var bucket: Array = by_archetype.get(archetype_id, [])
		bucket.append(index)
		by_archetype[archetype_id] = bucket

	var built: Array[MultiMeshInstance3D] = []
	for archetype_id: StringName in by_archetype:
		var instance := _build_bucket(archetype_id, by_archetype[archetype_id])
		if instance != null:
			instance.name = "Scatter_%d_%d_%s" % [chunk.x, chunk.y, String(archetype_id).replace(":", "_")]
			add_child(instance)
			built.append(instance)
	if not built.is_empty():
		_chunks[chunk] = built


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
		multimesh.set_instance_transform(slot, _transform_of(record))
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


func _transform_of(record: MapScatterLayer.Record) -> Transform3D:
	var centre := _terrain.cell_center(record.cell)
	var position := Vector3(
		centre.x + record.offset.x * _terrain.cell_size,
		0.0,
		centre.z + record.offset.y * _terrain.cell_size)
	# Высота — у рельефа, всегда. Объект, помнящий свою мировую Y, отрывается от
	# земли при первой же правке ландшафта (§9.3).
	position.y = _terrain.height_at(position)
	var basis := Basis(Vector3.UP, deg_to_rad(record.yaw_degrees)).scaled(Vector3.ONE * record.scale)
	return Transform3D(basis, position)


## Цвет экземпляра — тот же разброс `vary`, что у одиночной постановки, посеянный
## байтом варианта записи. Одна и та же карта поэтому окрашена одинаково при
## каждой загрузке, а соседние деревья — по-разному.
static func _colour_of(baked: ScatterMeshBaker.Baked, record: MapScatterLayer.Record) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([record.cell.x, record.cell.y, record.variant])
	return WorldAssetDef.jittered_color(baked.instance_colour_base, baked.instance_colour_vary, rng)
