extends SceneTree

## Ветер мира и качание растительности (`world_environment.md` §9,
## `map_fill_mode.md` §9.2.1).
##
## Тест существует из-за конкретной поломки: `GridTerrainWorld.set_wind` был
## написан, но его не вызывал никто, и трава террейна просто стояла. Молчаливо
## неподключённый потребитель глобального параметра не виден ни в одном обычном
## тесте — поэтому проверяется не формула качания, а то, что ветер доезжает.

const FOLIAGE_SHADER := "res://game/features/content/presentation/foliage_sway.gdshader"
const ASSETS := "res://game/features/content/presentation/assets/"


func _init() -> void:
	print("--- Running test_world_wind.gd ---")
	_test_globals_are_declared()
	_test_wind_reaches_the_shader_globals()
	_test_snapshot_wind_is_normalised_and_never_dead_still()
	_test_terrain_gets_the_same_wind()
	_test_a_board_built_later_still_gets_the_wind()
	_test_foliage_uses_the_shared_shader()
	_test_shader_foliage_can_still_be_tinted()
	print("--- test_world_wind.gd PASSED ---")
	quit(0)


## Шейдер объявляет `global uniform`; если параметра нет в project.godot, шейдер
## не компилируется, и падать это должно здесь, а не глазами в игре.
func _test_globals_are_declared() -> void:
	assert(WorldWind.globals_declared(),
		"world_wind_direction/world_wind_strength не объявлены в project.godot — "
		+ "шейдер листвы с ними не скомпилируется")


func _test_wind_reaches_the_shader_globals() -> void:
	WorldWind.set_wind(Vector2(0.0, 3.0), 0.8)
	var current := WorldWind.current()
	var direction: Vector2 = current["direction"]
	assert(direction.is_equal_approx(Vector2(0.0, 1.0)), "направление обязано доезжать нормализованным")
	assert(is_equal_approx(float(current["strength"]), 0.8))

	# Нулевое направление — не повод оставить шейдеру мусор.
	WorldWind.set_wind(Vector2.ZERO, 0.5)
	assert((WorldWind.current()["direction"] as Vector2).length() > 0.9)


func _test_snapshot_wind_is_normalised_and_never_dead_still() -> void:
	var snapshot := EnvironmentSnapshot.new()
	snapshot.wind_vector = Vector2(-4.0, 0.0)
	snapshot.wind_strength = 0.0
	WorldWind.apply(snapshot)
	var current := WorldWind.current()
	assert((current["direction"] as Vector2).is_equal_approx(Vector2.LEFT))
	# Полный штиль всё равно чуть шевелит листву: застывшая растительность
	# читается как сломанная игра, а не как безветренный день.
	assert(float(current["strength"]) >= WorldWind.MINIMUM_STIRRING)

	snapshot.wind_strength = 5.0
	WorldWind.apply(snapshot)
	assert(float(WorldWind.current()["strength"]) <= 1.0, "сила ветра обязана быть зажата")


## Трава террейна и листва наполнения получают один и тот же ветер из одного
## вызова. Здесь проверяется, что вызов доходит до террейна и не роняет ничего,
## когда террейна нет (лаборатория погоды, редактор); что ветер вообще
## публикуется в живой игре, стережёт `test_startup.gd`.
func _test_terrain_gets_the_same_wind() -> void:
	var axis := Vector2(1.0, 1.0).normalized()
	var terrain := GridTerrainWorld.new()
	WorldWind.set_wind(Vector2(1.0, 1.0), 0.6, terrain)
	assert((WorldWind.current()["direction"] as Vector2).is_equal_approx(axis))
	terrain.free()

	# Без террейна публикация обязана пройти: карту редактируют и без доски.
	WorldWind.set_wind(Vector2(1.0, 1.0), 0.6, null)
	assert(is_equal_approx(float(WorldWind.current()["strength"]), 0.6))

	# Материал травы террейна принимает тот же ветер — это его публичный контракт.
	var tall_grass := TerrainTallGrass.new()
	tall_grass.set_wind(Vector2(1.0, 1.0), 0.6)
	var material := tall_grass.material()
	assert((material.get_shader_parameter(&"wind_direction") as Vector2).is_equal_approx(axis))
	assert(is_equal_approx(float(material.get_shader_parameter(&"wind_strength")), 0.6))


## Редакторы и лаборатории строят доску один раз и не публикуют снимок погоды
## ни разу. Пока `attach` не существовал, трава там стояла неподвижно рядом с
## качающимися кустами — один параметр мира с двумя разными ответами на экране.
func _test_a_board_built_later_still_gets_the_wind() -> void:
	WorldWind.set_wind(Vector2(0.0, -1.0), 0.42)
	var terrain := GridTerrainWorld.new()
	WorldWind.attach(terrain)
	var current := WorldWind.current()
	assert((current["direction"] as Vector2).is_equal_approx(Vector2(0.0, -1.0)),
		"поздняя доска не должна менять направление уже опубликованного ветра")
	assert(is_equal_approx(float(current["strength"]), 0.42))
	terrain.free()

	# Отсутствующая доска — не ошибка: у погодной лаборатории её нет вовсе.
	WorldWind.attach(null)


func _test_foliage_uses_the_shared_shader() -> void:
	var shader := load(FOLIAGE_SHADER) as Shader
	assert(shader != null, "шейдер качания должен загружаться")
	for asset_id: StringName in [&"tree", &"conifer_tree", &"bush", &"grass_source", &"forage_source"]:
		var asset := WorldAssetCatalog.get_asset(asset_id)
		var instance := (load(asset.scene_path) as PackedScene).instantiate()
		var swaying := 0
		var static_wood := 0
		for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh := (node as MeshInstance3D).mesh
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var material := mesh.surface_get_material(0)
			if material is ShaderMaterial and (material as ShaderMaterial).shader == shader:
				swaying += 1
			else:
				static_wood += 1
		assert(swaying > 0, "%s: ни один меш не качается на ветру" % asset_id)
		instance.free()

	# Ствол на ветру не гнётся. Дерево, у которого качается всё, — резиновое.
	var tree := (load(ASSETS + "tree.tscn") as PackedScene).instantiate()
	for node: Node in (tree.get_node("Wood") as Node3D).get_children():
		var mesh := (node as MeshInstance3D).mesh
		assert(not (mesh.surface_get_material(0) is ShaderMaterial),
			"ствол и ветки не должны качаться вместе с кроной")
	tree.free()


## Перекраска обязана работать одинаково для обоих видов материала. Раньше
## тонирование умело только StandardMaterial3D, и перевод листвы на шейдер тихо
## сломал бы и разброс вариаций, и сезонные состояния.
func _test_shader_foliage_can_still_be_tinted() -> void:
	var tree := (load(ASSETS + "tree.tscn") as PackedScene).instantiate() as DecorObjectController
	tree.apply_decor_properties({"crown_color": "ff0000", "trunk_color": "0000ff"})

	var blob := tree.get_node("Crown/BlobA") as MeshInstance3D
	var blob_material := blob.material_override as ShaderMaterial
	assert(blob_material != null, "крона должна получить собственный шейдерный материал")
	var tint: Color = blob_material.get_shader_parameter(DecorObjectController.SHADER_ALBEDO)
	assert(tint.is_equal_approx(Color.RED), "цвет кроны не доехал до шейдера, получено %s" % tint)

	# Собственный материал на экземпляр, иначе перекраска одного дерева
	# перекрашивает лес.
	var other := (load(ASSETS + "tree.tscn") as PackedScene).instantiate() as DecorObjectController
	other.apply_decor_properties({"crown_color": "00ff00"})
	var other_tint: Color = ((other.get_node("Crown/BlobA") as MeshInstance3D).material_override as ShaderMaterial) \
		.get_shader_parameter(DecorObjectController.SHADER_ALBEDO)
	assert(other_tint.is_equal_approx(Color.GREEN))
	assert(tint.is_equal_approx(Color.RED), "второе дерево перекрасило первое")

	var trunk := tree.get_node("Wood/Trunk") as MeshInstance3D
	var trunk_material := trunk.material_override as StandardMaterial3D
	assert(trunk_material != null and trunk_material.albedo_color.is_equal_approx(Color.BLUE),
		"ствол по-прежнему тонируется как обычный материал")
	tree.free()
	other.free()
