class_name ScatterMeshBaker
extends RefCounted

## Сцена ассета → один меш, пригодный для `MultiMesh`
## (`map_fill_mode.md` §9.4).
##
## `MultiMesh` рисует ОДИН меш многократно, а ассет — это дерево нод: у ёлки
## ствол, комель и шесть ярусов лап, у оленя семнадцать нод. Инстансировать
## сцену на объект — это те самые двадцать нод и уникальный материал на каждое
## дерево (`FillObjectController._set_albedo` дублирует материал на экземпляр),
## то есть отсутствие всякого батчинга. Здесь дерево нод один раз сплавляется в
## многоповерхностный `ArrayMesh`: одна поверхность на материал, вершины уже в
## координатах корня.
##
## **Материал сохраняется, а не подменяется.** Листва остаётся на
## `foliage_sway.gdshader` и продолжает качаться от общего ветра, ствол остаётся
## `StandardMaterial3D`. Это и есть причина сплавлять по материалам, а не всё в
## одну поверхность.
##
## **Цвет экземпляра — отдельный разговор.** Массовому объекту нельзя дать свой
## материал, поэтому вариация цвета едет через `COLOR` экземпляра `MultiMesh`, а
## поверхности, которой этот цвет предназначен, albedo выставляется белым: цвет
## приходит от экземпляра, а не запечён в меш. Красится ОДНА поверхность — та,
## что привязана к первому цветовому контролу с `vary` (у растения это крона).
## Двух независимых цветов на экземпляр `MultiMesh` не бывает, и притворяться,
## что бывает, было бы хуже, чем сказать это здесь.

## Что получилось из ассета.
class Baked:
	extends RefCounted
	var mesh: ArrayMesh = null
	## Базовый цвет красящейся поверхности. Экземпляры получают его с дрожанием;
	## `Color.WHITE`, если красить нечего.
	var instance_colour_base := Color.WHITE
	## Сила дрожания из `vary` контрола. Ноль — вариаций цвета нет.
	var instance_colour_vary := 0.0
	## Радиус в метрах для отбраковки по расстоянию и для размеров AABB.
	var radius := 1.0

	func has_instance_colour() -> bool:
		return instance_colour_vary > 0.0


static var _cache: Dictionary = {}


## Кэш держится процессом: один и тот же ассет встречается на карте тысячи раз, а
## сплавление стоит инстансирования сцены. Сбрасывается вместе с каталогом.
static func clear_cache() -> void:
	_cache.clear()


static func bake(asset: WorldAssetDef) -> Baked:
	if asset == null:
		return null
	if _cache.has(asset.id):
		return _cache[asset.id]
	var scene := load(asset.scene_path) as PackedScene if ResourceLoader.exists(asset.scene_path) else null
	if scene == null:
		return null
	var root := scene.instantiate() as Node3D
	if root == null:
		return null

	var baked := Baked.new()
	var coloured_node := _instance_coloured_node(asset, baked)
	var surfaces: Dictionary = {}
	_collect(root, Transform3D.IDENTITY, surfaces, coloured_node)
	root.queue_free()

	baked.mesh = _assemble(surfaces)
	baked.radius = maxf(asset.size_m.x, asset.size_m.z) * 0.5
	_cache[asset.id] = baked
	return baked


## Имя ноды, которую красит экземпляр, плюс база и сила дрожания. Читается из
## `appearance_controls`, а не угадывается по имени: «крона» — это то, что автор
## ассета объявил цветным и варьирующимся, и ничто другое.
static func _instance_coloured_node(asset: WorldAssetDef, baked: Baked) -> StringName:
	for control: Dictionary in asset.appearance_controls:
		if String(control.get("type", "")) != WorldAssetDef.TYPE_COLOR:
			continue
		var vary := float(control.get("vary", 0.0))
		if vary <= 0.0:
			continue
		var binds: Variant = control.get("bind", null)
		if not (binds is Array) or (binds as Array).is_empty():
			continue
		var first: Variant = (binds as Array)[0]
		if not (first is Dictionary):
			continue
		baked.instance_colour_base = WorldAssetDef.to_color(control.get("default", Color.WHITE))
		baked.instance_colour_vary = vary
		return StringName((first as Dictionary).get("node", ""))
	return &""


static func _collect(
	node: Node,
	parent_transform: Transform3D,
	surfaces: Dictionary,
	coloured_node: StringName
) -> void:
	var here := parent_transform
	if node is Node3D:
		here = parent_transform * (node as Node3D).transform
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		_append_mesh(mesh_instance, here, surfaces, coloured_node)
	for child in node.get_children():
		_collect(child, here, surfaces, coloured_node)


static func _append_mesh(
	instance: MeshInstance3D,
	transform: Transform3D,
	surfaces: Dictionary,
	coloured_node: StringName
) -> void:
	var paints_from_instance := _is_under(instance, coloured_node)
	for surface_index in instance.mesh.get_surface_count():
		var material := instance.get_active_material(surface_index)
		var key := _surface_key(material, paints_from_instance)
		var tool: SurfaceTool = surfaces.get(key, null)
		if tool == null:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(_material_for(material, paints_from_instance))
			surfaces[key] = tool
		tool.append_from(instance.mesh, surface_index, transform)


## Красящаяся поверхность отделена от остальных даже при одинаковом материале:
## иначе ствол, нарисованный тем же материалом, что и крона, красился бы вместе
## с ней.
static func _surface_key(material: Material, paints_from_instance: bool) -> String:
	var base := str(material.get_instance_id()) if material != null else "none"
	return base + ("/instance" if paints_from_instance else "")


static func _material_for(material: Material, paints_from_instance: bool) -> Material:
	if not paints_from_instance or material == null:
		return material
	# Копия, а не оригинал: оригинал принадлежит сцене ассета, и его используют
	# одиночные, поставленные руками объекты со своим собственным цветом.
	var copy := material.duplicate() as Material
	if copy is ShaderMaterial:
		(copy as ShaderMaterial).set_shader_parameter(&"albedo_color", Color.WHITE)
	elif copy is StandardMaterial3D:
		var standard := copy as StandardMaterial3D
		standard.albedo_color = Color.WHITE
		standard.vertex_color_use_as_albedo = true
	return copy


static func _is_under(node: Node, ancestor_name: StringName) -> bool:
	if ancestor_name == &"":
		return false
	var probe := node
	while probe != null:
		if probe.name == ancestor_name:
			return true
		probe = probe.get_parent()
	return false


static func _assemble(surfaces: Dictionary) -> ArrayMesh:
	var mesh: ArrayMesh = null
	var keys: Array = surfaces.keys()
	# Порядок поверхностей стабилен: меш кэшируется и сравнивается, а поверхности
	# в случайном порядке сделали бы кэш недетерминированным.
	keys.sort()
	for key: String in keys:
		var tool: SurfaceTool = surfaces[key]
		tool.generate_normals()
		mesh = tool.commit(mesh)
	return mesh
