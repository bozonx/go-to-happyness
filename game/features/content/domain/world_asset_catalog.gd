class_name WorldAssetCatalog
extends RefCounted

## Catalog of world asset definitions and their category taxonomy
## (design_docs/engine/map_fill_mode.md §3, design_docs/engine/building_furnishing.md §5).
##
## The current vertical slice contains the built-in definitions below. Pack-owned
## asset definitions intentionally wait for their JSON format and first external
## consumer; there is no dead Resource-directory fallback or second loose-file
## source for editors to interpret differently.

const SCENE_DIR := "res://game/features/content/presentation/assets"

const GROUPS: Dictionary = {
	&"world": "Мир и природа",
	&"outdoor": "Экстерьер",
	&"furniture_living": "Мебель и быт",
	&"lighting_heating": "Освещение и отопление",
	&"equipment": "Оборудование",
	&"architecture": "Архитектурный декор",
}

const CATEGORIES: Dictionary = {
	# Outdoor (Экстерьер)
	&"camping": {"name": "Лагерь", "group": &"outdoor"},
	&"town": {"name": "Город и знаки", "group": &"outdoor"},
	&"nature": {"name": "Сад и озеленение", "group": &"outdoor"},
	&"street_furniture": {"name": "Уличная мебель", "group": &"outdoor"},
	# World and nature (Мир и природа) — map fill mode categories (map_fill_mode.md §3.2).
	&"vegetation": {"name": "Растительность", "group": &"world"},
	&"rocks_minerals": {"name": "Камни и минералы", "group": &"world"},
	&"creatures": {"name": "Существа", "group": &"world"},
	&"world_props": {"name": "Мировой реквизит", "group": &"world"},
	&"ambient": {"name": "Атмосфера", "group": &"world"},
	# Furniture and living (Мебель и быт)
	&"tables_seating": {"name": "Столы и сиденья", "group": &"furniture_living"},
	&"beds_storage": {"name": "Кровати и хранение вещей", "group": &"furniture_living"},
	&"utensils": {"name": "Утварь", "group": &"furniture_living"},
	&"cozy": {"name": "Текстиль и уют", "group": &"furniture_living"},
	# Lighting and heating (Освещение и отопление)
	&"lighting": {"name": "Светильники", "group": &"lighting_heating"},
	&"fires_stoves": {"name": "Костры, очаги и печи", "group": &"lighting_heating"},
	&"heating_ventilation": {"name": "Отопление и вентиляция", "group": &"lighting_heating"},
	# Equipment (Оборудование)
	&"industrial": {"name": "Промышленное оборудование", "group": &"equipment"},
	&"workbenches": {"name": "Верстаки и рабочие места", "group": &"equipment"},
	&"tools": {"name": "Инструменты и оснастка", "group": &"equipment"},
	&"kitchen_equipment": {"name": "Кухонное оборудование", "group": &"equipment"},
	&"storage_logistics": {"name": "Складское и логистическое оборудование", "group": &"equipment"},
	&"trade_service": {"name": "Торговое и сервисное оборудование", "group": &"equipment"},
	&"utility_sanitary": {"name": "Коммунальное и санитарное оборудование", "group": &"equipment"},
	# Architecture (Архитектурный декор)
	&"structural_decor": {"name": "Декор конструкций", "group": &"architecture"},
	&"wall_decor": {"name": "Настенный декор", "group": &"architecture"},
	&"roof_decor": {"name": "Декор крыш", "group": &"architecture"},
}

static var _assets: Dictionary = {}
static var load_errors: Array[String] = []
const PACK_ASSET_DIR := "assets"
const PACK_ASSET_SUFFIX := ".gdasset.json"


static func get_all_assets(scope: StringName = &"") -> Array[WorldAssetDef]:
	_ensure_catalog()
	var list: Array[WorldAssetDef] = []
	for asset: WorldAssetDef in _assets.values():
		if asset.is_in_scope(scope):
			list.append(asset)
	return list


## `scope` is `WorldAssetDef.SCOPE_BUILDING`, `SCOPE_MAP`, or empty for both
## palettes at once (design §3.2).
static func get_assets_by_category(
	category: StringName,
	scope: StringName = &""
) -> Array[WorldAssetDef]:
	_ensure_catalog()
	var list: Array[WorldAssetDef] = []
	for asset: WorldAssetDef in _assets.values():
		if asset.category == category and asset.is_in_scope(scope):
			list.append(asset)
	list.sort_custom(func(a: WorldAssetDef, b: WorldAssetDef) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return list


static func get_asset(id: StringName) -> WorldAssetDef:
	_ensure_catalog()
	return _assets.get(id, null)


static func has_asset(id: StringName) -> bool:
	_ensure_catalog()
	return _assets.has(id)


## How many assets each category holds — the editor greys out empty categories
## instead of dropping the author into a blank list.
static func category_counts(scope: StringName = &"") -> Dictionary:
	_ensure_catalog()
	var counts: Dictionary = {}
	for category_id in CATEGORIES.keys():
		counts[category_id] = 0
	for asset: WorldAssetDef in _assets.values():
		if not asset.is_in_scope(scope):
			continue
		counts[asset.category] = int(counts.get(asset.category, 0)) + 1
	return counts


## Categories of a group, or of every group when `group_id` is empty.
static func categories_in_group(group_id: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	for category_id in CATEGORIES.keys():
		if group_id == &"" or CATEGORIES[category_id]["group"] == group_id:
			list.append(category_id)
	return list


static func category_display_name(category_id: StringName) -> String:
	var info: Dictionary = CATEGORIES.get(category_id, {})
	return String(info.get("name", String(category_id)))


static func group_of_category(category_id: StringName) -> StringName:
	var info: Dictionary = CATEGORIES.get(category_id, {})
	return info.get("group", &"outdoor")


## First category that actually holds assets, so the catalog never opens empty.
static func first_populated_category(
	preferred: StringName = &"camping",
	scope: StringName = &""
) -> StringName:
	var counts := category_counts(scope)
	if int(counts.get(preferred, 0)) > 0:
		return preferred
	for category_id in CATEGORIES.keys():
		if int(counts.get(category_id, 0)) > 0:
			return category_id
	return preferred


## Filter assets by tag (design §5.2). Returns all assets if tag is empty.
static func get_assets_by_tag(tag: StringName, scope: StringName = &"") -> Array[WorldAssetDef]:
	_ensure_catalog()
	if tag == &"":
		return get_all_assets(scope)
	var list: Array[WorldAssetDef] = []
	for asset: WorldAssetDef in _assets.values():
		if tag in asset.tags and asset.is_in_scope(scope):
			list.append(asset)
	return list


## All tags currently represented in the catalog, in a stable display order.
## Tags are a secondary way to narrow a search; they deliberately do not form
## another level of the catalog tree.
static func all_tags(scope: StringName = &"") -> Array[StringName]:
	_ensure_catalog()
	var unique: Dictionary = {}
	for asset: WorldAssetDef in _assets.values():
		if not asset.is_in_scope(scope):
			continue
		for tag in asset.tags:
			unique[tag] = true
	var tags: Array[StringName] = []
	for tag in unique.keys():
		tags.append(tag)
	tags.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a).naturalnocasecmp_to(String(b)) < 0)
	return tags


## Combined filter for catalog UI (design §5.2).
## Empty / null filters are ignored.
static func filter_assets(
	p_category: StringName = &"",
	p_tag: StringName = &"",
	p_scope: StringName = &""
) -> Array[WorldAssetDef]:
	_ensure_catalog()
	var list: Array[WorldAssetDef] = []
	for asset: WorldAssetDef in _assets.values():
		if not asset.is_in_scope(p_scope):
			continue
		if p_category != &"" and asset.category != p_category:
			continue
		if p_tag != &"" and not (p_tag in asset.tags):
			continue
		list.append(asset)
	list.sort_custom(func(a: WorldAssetDef, b: WorldAssetDef) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return list


## Re-reads the on-disk asset directories. The editor calls this when entering
## decor mode so newly authored `.tres` files show up without a restart.
static func refresh() -> void:
	ContentIndex.invalidate()
	_assets.clear()
	load_errors.clear()
	_ensure_catalog()


static func _ensure_catalog() -> void:
	if not _assets.is_empty():
		return
	_register_builtin_assets()
	_load_pack_assets()


static func _load_pack_assets() -> void:
	for pack in ContentIndex.shared().content_packs():
		var root: String = pack.root_path.path_join(PACK_ASSET_DIR)
		if not DirAccess.dir_exists_absolute(root):
			continue
		var files := DirAccess.get_files_at(root)
		files.sort()
		for file_name: String in files:
			if not file_name.ends_with(PACK_ASSET_SUFFIX):
				continue
			var path := root.path_join(file_name)
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				load_errors.append("Некорректный world asset: %s" % path)
				continue
			var asset := _asset_from_dict(parsed as Dictionary, pack.id, pack.root_path)
			if asset == null:
				load_errors.append("World asset без id/scene: %s" % path)
				continue
			if _assets.has(asset.id):
				load_errors.append("Дубликат world asset %s: %s" % [asset.id, path])
				continue
			_register(asset)


static func _asset_from_dict(source: Dictionary, pack_id: StringName, pack_root: String) -> WorldAssetDef:
	var local_id := StringName(source.get("id", ""))
	var scene_path := String(source.get("scene", ""))
	if local_id == &"" or scene_path.is_empty():
		return null
	if not scene_path.begins_with("res://") and not scene_path.begins_with("user://"):
		scene_path = pack_root.path_join(scene_path)
	var asset := WorldAssetDef.new()
	asset.id = local_id if pack_id == &"core" else StringName("%s:%s" % [pack_id, local_id])
	asset.name = String(source.get("name", local_id))
	asset.category = StringName(source.get("category", "world_props"))
	asset.scene_path = scene_path
	asset.size_m = _vector3(source.get("size_m", []), Vector3.ONE)
	asset.size_in_blocks = Vector3i(_vector3(source.get("size_in_blocks", []), Vector3.ONE))
	asset.description = String(source.get("description", ""))
	asset.scope = StringName(source.get("scope", WorldAssetDef.SCOPE_MAP))
	asset.scale_mode = String(source.get("scale_mode", WorldAssetDef.SCALE_LOCKED))
	asset.collision_policy = String(source.get("collision", WorldAssetDef.COLLISION_NONE))
	asset.blocking_navigation = bool(source.get("blocking_navigation", false))
	var raw_scales: Variant = source.get("allowed_scales", null)
	if raw_scales is Array:
		asset.allowed_scales.clear()
		for value: Variant in raw_scales:
			asset.allowed_scales.append(float(value))
	var raw_controls: Variant = source.get("appearance", null)
	if raw_controls is Array:
		asset.appearance_controls.assign(raw_controls)
	var raw_tags: Variant = source.get("tags", null)
	if raw_tags is Array:
		for value: Variant in raw_tags:
			asset.tags.append(StringName(value))
	var raw_axes: Variant = source.get("rotation_axes", null)
	if raw_axes is Array:
		for value: Variant in raw_axes:
			asset.rotation_axes.append(String(value))
	var raw_placement: Variant = source.get("placement", null)
	if raw_placement is Dictionary:
		asset.placement = AssetPlacementPolicy.from_dict(raw_placement)
	return asset


static func _vector3(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Array or (value as Array).size() < 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _register_builtin_assets() -> void:
	_register(WorldAssetDef.new(
		&"campfire",
		"Костёр",
		&"fires_stoves",
		&"lighting_heating",
		SCENE_DIR.path_join("campfire.tscn"),
		Vector3i(1, 1, 1),
		1.0,
		[
			{
				"name": "visual_flame_visible", "label": "Горит", "type": "bool", "default": true,
				"bind": [
					{"node": "Fire", "prop": "visible"},
					{"node": "Embers", "prop": "emitting"},
					{"node": "Light", "prop": "visible"},
				],
			},
			{
				"name": "light_energy", "label": "Яркость света", "type": "float",
				"min": 0.0, "max": 5.0, "step": 0.1, "default": 1.8,
				"bind": [{"node": "Light", "prop": "light_energy"}],
			},
			{
				"name": "light_color", "label": "Цвет света", "type": "color",
				"default": Color("ffaa44"),
				"bind": [
					{"node": "Light", "prop": "light_color"},
					{"node": "Fire/FlameCore", "prop": WorldAssetDef.PROP_ALBEDO},
				],
			},
			{
				"name": "flame_height", "label": "Высота пламени", "type": "float",
				"min": 0.4, "max": 2.0, "step": 0.1, "default": 1.0,
				"bind": [{"node": "Fire", "prop": WorldAssetDef.PROP_SCALE_Y}],
			},
		],
		Vector3(1.3, 0.9, 1.3),
		"Кольцо камней, сложенные брёвна, живое пламя с искрами."
	))
	# Additional metadata for campfire
	var campfire := _assets[&"campfire"] as WorldAssetDef
	campfire.tags = [&"fire", &"light", &"cooking", &"outdoor"]
	campfire.scale_mode = WorldAssetDef.SCALE_LOCKED
	campfire.collision_policy = WorldAssetDef.COLLISION_SCENE
	campfire.blocking_navigation = true
	campfire.supported_capabilities = [&"fire_source", &"cooking_station", &"light_source"]
	campfire.state_variants = {
		"flame_full": {"visual_flame_visible": true, "light_energy": 1.8, "flame_height": 1.0},
		"flame_low": {"visual_flame_visible": true, "light_energy": 0.6, "flame_height": 0.55},
		"flame_none": {"visual_flame_visible": false, "light_energy": 0.0},
	}
	campfire.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_GENTLE
	)

	_register(WorldAssetDef.new(
		&"cooking_campfire",
		"Костёр для готовки",
		&"fires_stoves",
		&"lighting_heating",
		SCENE_DIR.path_join("cooking_campfire.tscn"),
		Vector3i(2, 2, 2),
		1.0,
		[
			{
				"name": "visual_flame_visible", "label": "Горит", "type": "bool", "default": true,
				"bind": [
					{"node": "Fire", "prop": "visible"},
					{"node": "Embers", "prop": "emitting"},
					{"node": "Light", "prop": "visible"},
				],
			},
			{
				"name": "light_energy", "label": "Яркость света", "type": "float",
				"min": 0.0, "max": 5.0, "step": 0.1, "default": 1.8,
				"bind": [{"node": "Light", "prop": "light_energy"}],
			},
			{
				"name": "has_pot", "label": "Котёл над огнём", "type": "bool", "default": true,
				"bind": [{"node": "Tripod", "prop": "visible"}],
			},
			{
				"name": "has_canopy", "label": "Навес", "type": "bool", "default": false,
				"bind": [{"node": "Canopy", "prop": "visible"}],
			},
		],
		Vector3(1.9, 1.6, 1.9),
		"Кольцо камней, тренога с котлом, опциональный навес."
	))
	var cooking := _assets[&"cooking_campfire"] as WorldAssetDef
	cooking.tags = [&"fire", &"light", &"cooking", &"outdoor"]
	cooking.scale_mode = WorldAssetDef.SCALE_LOCKED
	cooking.collision_policy = WorldAssetDef.COLLISION_SCENE
	cooking.blocking_navigation = true
	cooking.supported_capabilities = [&"fire_source", &"cooking_station", &"light_source"]
	cooking.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_GENTLE
	)
	cooking.placement.footprint_cells = Vector2i(2, 2)

	_register(WorldAssetDef.new(
		&"entrance_sign",
		"Въездной знак",
		&"town",
		&"outdoor",
		SCENE_DIR.path_join("entrance_sign.tscn"),
		Vector3i(2, 2, 1),
		1.0,
		[
			{
				"name": "sign_text", "label": "Текст на знаке", "type": "string",
				"default": "Happyness",
				"bind": [{"node": "Board/SignLabel", "prop": "text"}],
			},
			{
				"name": "board_color", "label": "Цвет щита", "type": "color",
				"default": Color("8a6549"),
				"bind": [{"node": "Board/BoardMesh", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_lantern", "label": "Фонарь", "type": "bool", "default": true,
				"bind": [{"node": "Lantern", "prop": "visible"}],
			},
			{
				"name": "light_energy", "label": "Яркость фонаря", "type": "float",
				"min": 0.0, "max": 4.0, "step": 0.1, "default": 1.4,
				"bind": [{"node": "Lantern/Light", "prop": "light_energy"}],
			},
		],
		Vector3(2.0, 2.4, 0.35),
		"Два столба, щит с надписью и подвесной фонарь."
	))
	var sign := _assets[&"entrance_sign"] as WorldAssetDef
	sign.tags = [&"sign", &"town", &"light"]
	sign.scale_mode = WorldAssetDef.SCALE_LOCKED
	sign.collision_policy = WorldAssetDef.COLLISION_SCENE
	sign.blocking_navigation = true
	sign.supported_capabilities = [&"light_source"]
	sign.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_MODERATE
	)
	sign.placement.footprint_cells = Vector2i(2, 1)

	_register(WorldAssetDef.new(
		&"flag",
		"Флаг",
		&"town",
		&"outdoor",
		SCENE_DIR.path_join("flag.tscn"),
		Vector3i(1, 3, 1),
		1.0,
		[
			{
				"name": "banner_color", "label": "Цвет полотнища", "type": "color",
				"default": Color("d45448"),
				"bind": [
					{"node": "Mast/Banner/BannerMesh", "prop": WorldAssetDef.PROP_ALBEDO},
					{"node": "Mast/Banner/BannerTail", "prop": WorldAssetDef.PROP_ALBEDO},
				],
			},
			{
				"name": "pole_height", "label": "Высота древка", "type": "float",
				"min": 0.6, "max": 2.0, "step": 0.05, "default": 1.0,
				"bind": [{"node": "Mast", "prop": WorldAssetDef.PROP_SCALE_Y}],
			},
			{
				"name": "has_banner", "label": "Полотнище", "type": "bool", "default": true,
				"bind": [{"node": "Mast/Banner", "prop": "visible"}],
			},
			{
				"name": "has_finial", "label": "Навершие", "type": "bool", "default": true,
				"bind": [{"node": "Mast/Finial", "prop": "visible"}],
			},
			{
				"name": "banner_text", "label": "Надпись", "type": "string", "default": "",
				"bind": [{"node": "Mast/Banner/BannerLabel", "prop": "text"}],
			},
		],
		Vector3(0.9, 2.6, 0.2),
		"Древко с навершием и полотнищем; цвет и надпись настраиваются."
	))
	var flag := _assets[&"flag"] as WorldAssetDef
	flag.tags = [&"town", &"sign"]
	flag.scale_mode = WorldAssetDef.SCALE_UNIFORM_STEPS
	flag.allowed_scales = [0.5, 1.0, 2.0]
	flag.collision_policy = WorldAssetDef.COLLISION_SCENE
	flag.blocking_navigation = true
	flag.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE],
		SlopeCatalog.CLASS_MODERATE
	)

	_register(WorldAssetDef.new(
		&"backpack",
		"Рюкзак",
		&"camping",
		&"outdoor",
		SCENE_DIR.path_join("backpack.tscn"),
		Vector3i(1, 1, 1),
		1.0,
		[
			{
				"name": "bag_color", "label": "Цвет рюкзака", "type": "color",
				"default": Color("8b5a2b"),
				"bind": [{"node": "Body", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_pocket", "label": "Передний карман", "type": "bool", "default": true,
				"bind": [{"node": "Pocket", "prop": "visible"}],
			},
		],
		Vector3(0.5, 0.6, 0.4),
		"Походный рюкзак с карманами и ремнями для хранения предметов."
	))
	var backpack := _assets[&"backpack"] as WorldAssetDef
	backpack.tags = [&"storage", &"equipment", &"outdoor", &"camping"]
	backpack.scale_mode = WorldAssetDef.SCALE_UNIFORM_STEPS
	backpack.allowed_scales = [0.8, 1.0, 1.2, 1.5]
	backpack.collision_policy = WorldAssetDef.COLLISION_SCENE
	backpack.scope = WorldAssetDef.SCOPE_BOTH
	backpack.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE],
		SlopeCatalog.CLASS_MODERATE
	)

	_register_natural_assets()


## Vegetation, minerals and wildlife (design §3.2, `map_fill_mode.md`).
##
## Everything here shares one authoring idea: two copies of the same asset must be
## able to look different without becoming two assets. Size and colour are
## `vary`-marked controls, so the fill-mode brush can draw a forest that is not a
## row of clones (§7.6), and a season or a depleted state is a `state_variants`
## entry rather than a colour literal in whichever service happens to notice.
static func _register_natural_assets() -> void:
	var tree := _natural(
		&"tree", "Дерево", &"vegetation", "tree.tscn", Vector3(2.9, 5.3, 2.6),
		"Лиственное дерево с шапкой из нескольких крон. Даёт древесину и ветки.",
		_foliage_controls(&"Crown", &"Wood", Color("3f7a3a"), Color("5c4432"))
	)
	tree.tags = [&"vegetation", &"tree", &"wood", &"forest"]
	tree.collision_policy = WorldAssetDef.COLLISION_SCENE
	tree.blocking_navigation = true
	tree.supported_capabilities = [&"wood_source", &"branch_source"]
	tree.state_variants = _foliage_states(Color("3f7a3a"), Color("2f5c34"))
	_scalable(tree, 0.8, 1.3)

	var conifer := _natural(
		&"conifer_tree", "Хвойное дерево", &"vegetation", "conifer_tree.tscn",
		Vector3(2.6, 4.7, 2.6),
		"Ель с ярусами лап. Тот же источник древесины, другой силуэт: север, горы, тайга.",
		_foliage_controls(&"Crown", &"Wood", Color("295a3e"), Color("4c3628"))
	)
	conifer.tags = [&"vegetation", &"tree", &"wood", &"forest", &"boreal"]
	conifer.collision_policy = WorldAssetDef.COLLISION_SCENE
	conifer.blocking_navigation = true
	conifer.supported_capabilities = [&"wood_source", &"branch_source"]
	# A spruce keeps its needles: no autumn, and winter is snow rather than a
	# colour change. Declaring only the variants the plant really has is what
	# stops a seasonal pass from painting evergreens orange.
	conifer.state_variants = {
		"summer": {"crown_color": "295a3e"},
		"withered": {"crown_color": "6b5a3a"},
		"winter": {"crown_color": "224834", "has_snow": true},
	}
	_scalable(conifer, 0.8, 1.35)

	var bush_controls := _foliage_controls(
		&"Foliage", &"Twigs", Color("4d8042"), Color("66513c"), ""
	)
	bush_controls.append({
		"name": "has_twigs", "label": "Торчащие ветки", "type": "bool",
		"default": true, "vary": 0.8,
		"bind": [{"node": "Twigs", "prop": "visible"}],
	})
	var bush := _natural(
		&"bush", "Куст", &"vegetation", "bush.tscn", Vector3(1.2, 0.95, 1.2),
		"Низкий кустарник с торчащими ветками. Даёт только ветки, древесины в нём нет.",
		bush_controls
	)
	bush.tags = [&"vegetation", &"bush", &"branches"]
	bush.supported_capabilities = [&"branch_source"]
	bush.state_variants = _foliage_states(Color("4d8042"), Color("3d6636"), false)
	_scalable(bush, 0.7, 1.4)

	var grass := _natural(
		&"grass_source", "Трава", &"vegetation", "grass_source.tscn",
		Vector3(0.6, 0.75, 0.6),
		"Пучок травы с колосками. Сырьё для подстилок, верёвок и кровли.",
		[
			{
				"name": "blade_color", "label": "Цвет травы", "type": "color",
				"default": Color("65a34d"), "vary": 0.55,
				"bind": [{"node": "Blades", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "tuft_size", "label": "Размер пучка", "type": "float",
				"min": 0.6, "max": 1.4, "step": 0.05, "default": 1.0, "vary": 0.25,
				"bind": [{"node": "Blades", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_seed_heads", "label": "Колоски", "type": "bool",
				"default": true, "vary": 0.6,
				"bind": [{"node": "SeedHeads", "prop": "visible"}],
			},
		]
	)
	grass.tags = [&"vegetation", &"grass", &"harvest"]
	grass.supported_capabilities = [&"grass_source"]
	grass.state_variants = {
		"summer": {"blade_color": "65a34d", "has_seed_heads": true},
		"autumn": {"blade_color": "b39a52", "has_seed_heads": true},
		"withered": {"blade_color": "8a7a4a", "has_seed_heads": false},
	}
	_scalable(grass, 0.7, 1.4)

	var forage := _natural(
		&"forage_source", "Дикая пища", &"vegetation", "forage_source.tscn",
		Vector3(0.7, 0.45, 0.7),
		"Съедобное растение с ягодами. Один сбор — и его нет до конца сессии.",
		[
			{
				"name": "berry_color", "label": "Цвет ягод", "type": "color",
				"default": Color("c43c3d"), "vary": 0.45,
				"bind": [{"node": "Berries", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "leaf_color", "label": "Цвет листвы", "type": "color",
				"default": Color("5c8b43"), "vary": 0.4,
				"bind": [{"node": "Foliage", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_berries", "label": "Ягоды", "type": "bool", "default": true,
				"bind": [{"node": "Berries", "prop": "visible"}],
			},
		]
	)
	forage.tags = [&"vegetation", &"food", &"harvest"]
	forage.supported_capabilities = [&"forage_source"]
	forage.state_variants = {
		"ripe": {"has_berries": true},
		"picked": {"has_berries": false},
	}
	_scalable(forage, 0.8, 1.3)

	var boulder := _natural(
		&"boulder", "Валун", &"rocks_minerals", "boulder.tscn", Vector3(1.8, 0.9, 1.6),
		"Гранёный камень с осколками у основания. Перекрывает проход.",
		[
			{
				"name": "rock_color", "label": "Цвет камня", "type": "color",
				"default": Color("7a7e83"), "vary": 0.4,
				"bind": [{"node": "Rock", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "rock_size", "label": "Размер", "type": "float",
				"min": 0.6, "max": 1.5, "step": 0.05, "default": 1.0, "vary": 0.3,
				"bind": [{"node": "Rock", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_moss", "label": "Мох", "type": "bool",
				"default": false, "vary": 0.35,
				"bind": [{"node": "Moss", "prop": "visible"}],
			},
		]
	)
	boulder.tags = [&"rock", &"stone", &"obstacle"]
	boulder.collision_policy = WorldAssetDef.COLLISION_SCENE
	boulder.blocking_navigation = true
	# A rock is the one thing that may sit in a stream bed or on a beach, so its
	# surfaces are wider than the vegetation default.
	boulder.placement = AssetPlacementPolicy.of_surfaces(
		[
			AssetPlacementPolicy.SURFACE_GROUND,
			AssetPlacementPolicy.SURFACE_SHALLOW,
			AssetPlacementPolicy.SURFACE_ICE,
		],
		SlopeCatalog.CLASS_STEEP,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	_scalable(boulder, 0.6, 1.8)

	var ore := _natural(
		&"ore_deposit", "Залежь руды", &"rocks_minerals", "ore_deposit.tscn",
		Vector3(1.8, 0.7, 1.5),
		"Выход породы с жилами. Цвет жилы задаёт, что это за руда.",
		[
			{
				"name": "ore_color", "label": "Цвет жилы", "type": "color",
				"default": Color("d4963f"), "vary": 0.25,
				"bind": [{"node": "Veins", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "rock_color", "label": "Цвет породы", "type": "color",
				"default": Color("5c5e65"), "vary": 0.3,
				"bind": [{"node": "Rock", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
		]
	)
	ore.tags = [&"rock", &"ore", &"resource"]
	ore.collision_policy = WorldAssetDef.COLLISION_SCENE
	ore.blocking_navigation = true
	# One asset, every ore: the vein colour is authored, so adding "оловянная
	# руда" is a pack archetype rather than a scene and a commit here.
	ore.state_variants = {
		"copper": {"ore_color": "d4963f"},
		"iron": {"ore_color": "9a5f4a"},
		"coal": {"ore_color": "2e2c2b"},
		"depleted": {"ore_color": "6b6b68"},
	}
	_scalable(ore, 0.7, 1.4)

	var rabbit := _natural(
		&"rabbit", "Кролик", &"creatures", "rabbit.tscn", Vector3(0.55, 0.45, 0.35),
		"Дикий кролик: мясо и шкура для того, кто его догонит.",
		[
			{
				"name": "fur_color", "label": "Цвет шерсти", "type": "color",
				"default": Color("afa493"), "vary": 0.4,
				"bind": [{"node": "Fur", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
		]
	)
	rabbit.tags = [&"creature", &"food", &"hunting"]
	rabbit.scope = WorldAssetDef.SCOPE_MAP

	# Fireflies are a non-physical ambient effect (a MultiMesh of glowing points),
	# so neither a collider nor navigation blocking applies. It drives itself from
	# the published `EnvironmentSnapshot` like any other `AmbientEffect`, and its
	# scene stays with the ambient effects — the catalog references assets, it does
	# not have to own every file.
	var fireflies := WorldAssetDef.new(
		&"fireflies", "Светлячки", &"ambient", &"world",
		"res://game/features/world/presentation/ambient/fireflies_effect.tscn",
		Vector3i.ONE, 1.0, [], Vector3(4.0, 3.0, 4.0),
		"Рой светлячков; количество, радиус и высота задаются свойствами сущности."
	)
	fireflies.tags = [&"ambient", &"light", &"night"]
	fireflies.rotation_axes = ["y"]
	fireflies.scope = WorldAssetDef.SCOPE_MAP
	fireflies.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE],
		SlopeCatalog.CLASS_CLIFF
	)
	_register(fireflies)

	_register_biome_vegetation()
	_register_mineral_assets()
	_register_wildlife_assets()
	_register_human_traces()
	_register_ambient_effects()


## The rest of the vegetation the world generator places (`map_fill_mode.md` §3.2).
##
## Every entry here exists because a biome needs a *silhouette* the first batch
## cannot give it: a birch grove is not a green tree with a different tint, and a
## palm is not a spruce. Where only the colour differs, the answer stays `vary` or
## a `state_variants` entry — that is why there is no "autumn tree" asset.
static func _register_biome_vegetation() -> void:
	var birch := _natural(
		&"birch_tree", "Берёза", &"vegetation", "birch_tree.tscn", Vector3(2.0, 5.4, 1.9),
		"Светлый ствол с чёрными отметинами и редкая крона. Тот же лес, другой силуэт: "
		+ "берёзовая роща читается издалека даже посреди хвойного массива.",
		_foliage_controls(&"Crown", &"Wood", Color("92bf51"), Color("e6e4dc"))
	)
	birch.tags = [&"vegetation", &"tree", &"wood", &"forest"]
	birch.collision_policy = WorldAssetDef.COLLISION_SCENE
	birch.blocking_navigation = true
	birch.supported_capabilities = [&"wood_source", &"branch_source"]
	birch.state_variants = _foliage_states(Color("92bf51"), Color("8a7b63"))
	_scalable(birch, 0.8, 1.25)

	var dead := _natural(
		&"dead_tree", "Сухостой", &"vegetation", "dead_tree.tscn", Vector3(2.4, 3.3, 1.6),
		"Мёртвое дерево без кроны. Древесину даёт, ветки — нет: они с него давно осыпались.",
		[
			{
				"name": "trunk_color", "label": "Цвет древесины", "type": "color",
				"default": Color("7b6f5f"), "vary": 0.4,
				"bind": [{"node": "Lean/Wood", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_branches", "label": "Обломки сучьев", "type": "bool",
				"default": true, "vary": 0.75,
				"bind": [{"node": "Lean/Branches", "prop": "visible"}],
			},
			{
				# Наклон — единственный способ отличить два сухих ствола друг от
				# друга, когда у них нет ни кроны, ни цвета листвы.
				"name": "lean", "label": "Наклон", "type": "float",
				"min": -12.0, "max": 12.0, "step": 1.0, "default": 0.0, "vary": 7.0,
				"bind": [{"node": "Lean", "prop": "rotation_degrees:z"}],
			},
		]
	)
	dead.tags = [&"vegetation", &"tree", &"wood", &"dead"]
	dead.collision_policy = WorldAssetDef.COLLISION_SCENE
	dead.blocking_navigation = true
	dead.supported_capabilities = [&"wood_source"]
	# Сухое дерево не знает сезонов — оно уже мертво. Зато знает, отчего умерло:
	# сушь и гарь выглядят по-разному.
	dead.state_variants = {
		"dry": {"trunk_color": "7b6f5f"},
		"burnt": {"trunk_color": "3a3532", "has_branches": false},
	}
	_scalable(dead, 0.8, 1.3)

	var stump := _natural(
		&"stump", "Пень", &"vegetation", "stump.tscn", Vector3(1.3, 0.7, 1.05),
		"Спил со следом топора. Ставится кластерами: это память о старой вырубке, а не одинокий пень.",
		[
			{
				"name": "wood_color", "label": "Цвет древесины", "type": "color",
				"default": Color("5c4736"), "vary": 0.35,
				"bind": [{"node": "Wood", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "stump_size", "label": "Размер", "type": "float",
				"min": 0.7, "max": 1.35, "step": 0.05, "default": 1.0, "vary": 0.25,
				"bind": [{"node": "Wood", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_moss", "label": "Мох", "type": "bool",
				"default": false, "vary": 0.5,
				"bind": [{"node": "Moss", "prop": "visible"}],
			},
		]
	)
	stump.tags = [&"vegetation", &"wood", &"stump"]
	stump.supported_capabilities = [&"wood_source"]
	_scalable(stump, 0.75, 1.35)

	var fern := _natural(
		&"fern", "Папоротник", &"vegetation", "fern.tscn", Vector3(0.95, 0.85, 1.1),
		"Розетка вай в тени полога. Ничего не даёт, зато отличает лес от редколесья.",
		[
			{
				"name": "frond_color", "label": "Цвет вай", "type": "color",
				"default": Color("3e7342"), "vary": 0.5,
				"bind": [{"node": "Fronds", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "fern_size", "label": "Размер", "type": "float",
				"min": 0.65, "max": 1.4, "step": 0.05, "default": 1.0, "vary": 0.3,
				"bind": [{"node": "Fronds", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_shoots", "label": "Молодые побеги", "type": "bool",
				"default": true, "vary": 0.55,
				"bind": [{"node": "Shoots", "prop": "visible"}],
			},
		]
	)
	fern.tags = [&"vegetation", &"undergrowth", &"forest"]
	fern.state_variants = {
		"summer": {"frond_color": "3e7342", "has_shoots": true},
		"autumn": {"frond_color": "8a7a3c", "has_shoots": false},
		"withered": {"frond_color": "6b5a38", "has_shoots": false},
	}
	_scalable(fern, 0.7, 1.4)

	var reeds := _natural(
		&"reeds", "Камыш", &"vegetation", "reeds.tscn", Vector3(0.8, 1.55, 1.0),
		"Стебли на мелководье. Сырьё для кровли и плетения; на суше выглядит ошибкой — политика это и говорит.",
		[
			{
				"name": "stalk_color", "label": "Цвет стеблей", "type": "color",
				"default": Color("7e9c53"), "vary": 0.45,
				"bind": [{"node": "Stalks", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "reed_height", "label": "Высота", "type": "float",
				"min": 0.7, "max": 1.4, "step": 0.05, "default": 1.0, "vary": 0.3,
				"bind": [{"node": "Stalks", "prop": WorldAssetDef.PROP_SCALE_Y}],
			},
			{
				"name": "has_cattails", "label": "Початки", "type": "bool",
				"default": true, "vary": 0.55,
				"bind": [{"node": "Cattails", "prop": "visible"}],
			},
		]
	)
	reeds.tags = [&"vegetation", &"grass", &"water", &"harvest"]
	reeds.supported_capabilities = [&"grass_source"]
	reeds.state_variants = {
		"summer": {"stalk_color": "7e9c53", "has_cattails": true},
		"autumn": {"stalk_color": "b3a15c", "has_cattails": true},
		"withered": {"stalk_color": "8a7c52", "has_cattails": false},
	}
	# Единственная растительность, которой суша противопоказана: политика
	# `require` — это и есть «камыш растёт в воде», записанное так, что редактор
	# может об этом предупредить.
	reeds.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_SHALLOW],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_REQUIRE
	)
	reeds.placement.align_to_normal = AssetPlacementPolicy.ALIGN_NONE
	reeds.placement.vertical_offset = -0.12
	_scalable(reeds, 0.8, 1.3)

	var cactus := _natural(
		&"cactus", "Кактус", &"vegetation", "cactus.tscn", Vector3(1.8, 2.15, 0.6),
		"Ребристая колонна с отростками. Единственное, что стоит вертикально посреди пустыни.",
		[
			{
				"name": "flesh_color", "label": "Цвет мякоти", "type": "color",
				"default": Color("47734a"), "vary": 0.3,
				"bind": [{"node": "Body", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_arms", "label": "Отростки", "type": "bool",
				"default": true, "vary": 0.6,
				"bind": [{"node": "Body/Arms", "prop": "visible"}],
			},
			{
				"name": "has_flowers", "label": "Цветы", "type": "bool",
				"default": false, "vary": 0.25,
				"bind": [{"node": "Flowers", "prop": "visible"}],
			},
		]
	)
	cactus.tags = [&"vegetation", &"desert", &"obstacle"]
	cactus.collision_policy = WorldAssetDef.COLLISION_SCENE
	cactus.blocking_navigation = true
	cactus.state_variants = {
		"bloom": {"has_flowers": true},
		"plain": {"has_flowers": false},
		"withered": {"flesh_color": "6b7a4a", "has_flowers": false},
	}
	_scalable(cactus, 0.7, 1.4)

	var palm_controls := _foliage_controls(
		&"Crown", &"Wood", Color("4d8b45"), Color("8c7353"), ""
	)
	palm_controls.append({
		"name": "has_coconuts", "label": "Плоды", "type": "bool",
		"default": false, "vary": 0.4,
		"bind": [{"node": "Coconuts", "prop": "visible"}],
	})
	var palm := _natural(
		&"palm_tree", "Пальма", &"vegetation", "palm_tree.tscn", Vector3(2.7, 5.4, 2.4),
		"Изогнутый ствол и веер листьев. Тропики и оазисы; снега у неё не бывает.",
		palm_controls
	)
	palm.tags = [&"vegetation", &"tree", &"wood", &"tropical"]
	palm.collision_policy = WorldAssetDef.COLLISION_SCENE
	palm.blocking_navigation = true
	palm.supported_capabilities = [&"wood_source", &"branch_source"]
	# Ни осени, ни зимы: объявить их означало бы разрешить сезонному проходу
	# покрасить пальму в жёлтое и присыпать снегом.
	palm.state_variants = {
		"summer": {"crown_color": "4d8b45"},
		"withered": {"crown_color": "8a7a48"},
	}
	_scalable(palm, 0.85, 1.25)

	var acacia := _natural(
		&"acacia_tree", "Акация", &"vegetation", "acacia_tree.tscn", Vector3(3.4, 4.0, 3.3),
		"Плоская зонтичная крона на кривом стволе. В саванне стоит одиночками, а не массивом.",
		_foliage_controls(&"Crown", &"Wood", Color("6b8442"), Color("60513e"), "")
	)
	acacia.tags = [&"vegetation", &"tree", &"wood", &"savanna"]
	acacia.collision_policy = WorldAssetDef.COLLISION_SCENE
	acacia.blocking_navigation = true
	acacia.supported_capabilities = [&"wood_source", &"branch_source"]
	acacia.state_variants = {
		"summer": {"crown_color": "6b8442"},
		"dry": {"crown_color": "9c8f4e"},
		"withered": {"crown_color": "7a6a3c"},
	}
	_scalable(acacia, 0.85, 1.3)

	var moss := _natural(
		&"moss_patch", "Мох", &"vegetation", "moss_patch.tscn", Vector3(1.25, 0.15, 1.25),
		"Подушки мха с лишайником. Массовый ковёр там, где трава уже не растёт: тундра, гольцы, полярная пустыня.",
		[
			{
				"name": "moss_color", "label": "Цвет мха", "type": "color",
				"default": Color("5a794a"), "vary": 0.45,
				"bind": [{"node": "Moss", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "patch_size", "label": "Размер пятна", "type": "float",
				"min": 0.6, "max": 1.5, "step": 0.05, "default": 1.0, "vary": 0.35,
				"bind": [{"node": "Moss", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_lichen", "label": "Лишайник", "type": "bool",
				"default": true, "vary": 0.5,
				"bind": [{"node": "Lichen", "prop": "visible"}],
			},
		]
	)
	moss.tags = [&"vegetation", &"tundra", &"ground_cover"]
	moss.state_variants = {
		"summer": {"moss_color": "5a794a"},
		"withered": {"moss_color": "7a7a5c"},
		"winter": {"moss_color": "6e7a68"},
	}
	moss.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE],
		SlopeCatalog.CLASS_STEEP
	)
	_scalable(moss, 0.7, 1.5)


## Stone the terrain layer cannot express: it owns the ground surface, not the
## things lying on it (`grid_terrain_system.md`). A scree slope is a scatter of
## objects, and drawing it as terrain would make it unremovable.
static func _register_mineral_assets() -> void:
	var cluster := _natural(
		&"rock_cluster", "Россыпь камней", &"rocks_minerals", "rock_cluster.tscn",
		Vector3(1.25, 0.4, 1.1),
		"Горсть камней одним объектом. Осыпь из тридцати валунов — это тридцать инстансов, из россыпей — пять.",
		[
			{
				"name": "rock_color", "label": "Цвет камня", "type": "color",
				"default": Color("857f7c"), "vary": 0.35,
				"bind": [{"node": "Rocks", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "cluster_size", "label": "Размер россыпи", "type": "float",
				"min": 0.6, "max": 1.5, "step": 0.05, "default": 1.0, "vary": 0.3,
				"bind": [{"node": "Rocks", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_moss", "label": "Мох", "type": "bool",
				"default": false, "vary": 0.35,
				"bind": [{"node": "Moss", "prop": "visible"}],
			},
		]
	)
	cluster.tags = [&"rock", &"stone", &"scree"]
	# Через россыпь переступают: делать её препятствием значило бы перегородить
	# каждую осыпь, по которой персонаж обязан пройти.
	cluster.placement = AssetPlacementPolicy.of_surfaces(
		[
			AssetPlacementPolicy.SURFACE_GROUND,
			AssetPlacementPolicy.SURFACE_SHALLOW,
			AssetPlacementPolicy.SURFACE_ICE,
		],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	_scalable(cluster, 0.7, 1.5)

	var outcrop := _natural(
		&"stone_outcrop", "Скальный выход", &"rocks_minerals", "stone_outcrop.tscn",
		Vector3(3.8, 2.7, 2.1),
		"Плиты коренной породы, вышедшие наружу. Ставится на крутых склонах — там, где почвы уже нет.",
		[
			{
				"name": "rock_color", "label": "Цвет породы", "type": "color",
				"default": Color("737a7f"), "vary": 0.3,
				"bind": [{"node": "Rock", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "outcrop_size", "label": "Размер", "type": "float",
				"min": 0.7, "max": 1.5, "step": 0.05, "default": 1.0, "vary": 0.25,
				"bind": [{"node": "Rock", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_moss", "label": "Мох", "type": "bool",
				"default": false, "vary": 0.4,
				"bind": [{"node": "Moss", "prop": "visible"}],
			},
		]
	)
	outcrop.tags = [&"rock", &"stone", &"obstacle", &"cliff"]
	outcrop.collision_policy = WorldAssetDef.COLLISION_SCENE
	outcrop.blocking_navigation = true
	outcrop.placement = AssetPlacementPolicy.of_surfaces(
		[
			AssetPlacementPolicy.SURFACE_GROUND,
			AssetPlacementPolicy.SURFACE_SHALLOW,
			AssetPlacementPolicy.SURFACE_ICE,
		],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	outcrop.placement.footprint_cells = Vector2i(2, 2)
	_scalable(outcrop, 0.7, 1.6)

	var clay := _natural(
		&"clay_pit", "Глиняная яма", &"rocks_minerals", "clay_pit.tscn",
		Vector3(2.4, 0.35, 2.3),
		"Размытый берег с обнажённой глиной и отвалом. Пойма и старица — единственное, где она бывает.",
		[
			{
				"name": "clay_color", "label": "Цвет глины", "type": "color",
				"default": Color("9d6f52"), "vary": 0.3,
				"bind": [{"node": "Clay", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "pit_size", "label": "Размер", "type": "float",
				"min": 0.7, "max": 1.4, "step": 0.05, "default": 1.0, "vary": 0.25,
				"bind": [{"node": "Clay", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_puddle", "label": "Вода в яме", "type": "bool",
				"default": true, "vary": 0.45,
				"bind": [{"node": "Puddle", "prop": "visible"}],
			},
		]
	)
	clay.tags = [&"clay", &"resource", &"shore"]
	clay.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_SHALLOW],
		SlopeCatalog.CLASS_GENTLE,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	clay.placement.footprint_cells = Vector2i(2, 2)
	_scalable(clay, 0.8, 1.4)

	var sand := _natural(
		&"sand_patch", "Песчаная отмель", &"rocks_minerals", "sand_patch.tscn",
		Vector3(3.4, 0.2, 2.9),
		"Наносы песка с рябью. Кладётся по берегам и в поймах поверх любой поверхности.",
		[
			{
				"name": "sand_color", "label": "Цвет песка", "type": "color",
				"default": Color("d4c192"), "vary": 0.3,
				"bind": [{"node": "Sand", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "patch_size", "label": "Размер", "type": "float",
				"min": 0.6, "max": 1.6, "step": 0.05, "default": 1.0, "vary": 0.35,
				"bind": [{"node": "Sand", "prop": WorldAssetDef.PROP_SCALE}],
			},
			{
				"name": "has_pebbles", "label": "Галька", "type": "bool",
				"default": true, "vary": 0.5,
				"bind": [{"node": "Pebbles", "prop": "visible"}],
			},
		]
	)
	sand.tags = [&"sand", &"ground_cover", &"shore"]
	sand.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_SHALLOW],
		SlopeCatalog.CLASS_GENTLE,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	sand.placement.footprint_cells = Vector2i(2, 2)
	_scalable(sand, 0.8, 1.6)


## Wildlife. The mechanics are already here — `WanderHabit` decides how a creature
## drifts, `AmbientLifeService` moves all of them — so a new animal is a scene, a
## catalog entry and an archetype with a `wander` component. Nothing below knows
## what "grazing" means, and that is the point.
static func _register_wildlife_assets() -> void:
	var deer := _natural(
		&"deer", "Олень", &"creatures", "deer.tscn", Vector3(1.4, 1.8, 0.6),
		"Пасётся стадом по опушкам. Мясо и шкура — тому, кто сумеет подойти.",
		[
			{
				"name": "fur_color", "label": "Цвет шерсти", "type": "color",
				"default": Color("a2764d"), "vary": 0.35,
				"bind": [{"node": "Fur", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_antlers", "label": "Рога", "type": "bool",
				"default": true, "vary": 0.5,
				"bind": [{"node": "Antlers", "prop": "visible"}],
			},
		]
	)
	deer.tags = [&"creature", &"food", &"hunting"]
	deer.scope = WorldAssetDef.SCOPE_MAP
	_scalable(deer, 0.9, 1.15)

	var boar := _natural(
		&"boar", "Кабан", &"creatures", "boar.tscn", Vector3(1.3, 0.8, 0.6),
		"Роется в подлеске и не уступает дорогу. Мясо и щетина.",
		[
			{
				"name": "fur_color", "label": "Цвет щетины", "type": "color",
				"default": Color("51453d"), "vary": 0.3,
				"bind": [{"node": "Fur", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_tusks", "label": "Клыки", "type": "bool",
				"default": true, "vary": 0.7,
				"bind": [{"node": "Tusks", "prop": "visible"}],
			},
		]
	)
	boar.tags = [&"creature", &"food", &"hunting"]
	boar.scope = WorldAssetDef.SCOPE_MAP
	_scalable(boar, 0.9, 1.2)

	var wolf := _natural(
		&"wolf", "Волк", &"creatures", "wolf.tscn", Vector3(1.5, 0.95, 0.45),
		"Обходит свой участок в глубине леса. Ставится подальше от старта — это угроза, а не добыча.",
		[
			{
				"name": "fur_color", "label": "Цвет шерсти", "type": "color",
				"default": Color("798084"), "vary": 0.35,
				"bind": [{"node": "Fur", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
		]
	)
	wolf.tags = [&"creature", &"predator", &"threat"]
	wolf.scope = WorldAssetDef.SCOPE_MAP
	_scalable(wolf, 0.9, 1.15)

	var bird := _natural(
		&"bird", "Птица", &"creatures", "bird.tscn", Vector3(0.4, 0.2, 0.25),
		"Одна птица стаи: держится своих благодаря повадке `flocking`. Стая — это несколько"
		+ " постановок рядом, а не отдельный объект с числом внутри.",
		[
			{
				"name": "plumage_color", "label": "Цвет оперения", "type": "color",
				"default": Color("45434c"), "vary": 0.5,
				"bind": [{"node": "Plumage", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
		]
	)
	bird.tags = [&"creature", &"bird", &"ambient"]
	bird.scope = WorldAssetDef.SCOPE_MAP
	# Птица держится над поверхностью, в том числе над водой: подъём авторский,
	# высота самой поверхности по-прежнему принадлежит рельефу (§9.3).
	bird.placement = AssetPlacementPolicy.of_surfaces(
		[
			AssetPlacementPolicy.SURFACE_GROUND,
			AssetPlacementPolicy.SURFACE_SHALLOW,
			AssetPlacementPolicy.SURFACE_WATER,
			AssetPlacementPolicy.SURFACE_ICE,
		],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	bird.placement.align_to_normal = AssetPlacementPolicy.ALIGN_NONE
	bird.placement.vertical_offset = 1.4
	_scalable(bird, 0.8, 1.2)


## Traces of people who were here before the player (`map_fill_mode.md` §3.2).
##
## None of it carries a mechanic: these are inert props whose whole job is to say
## "this place has a history". They are ordinary assets rather than a special
## "decoration" kind, because the moment ruins acquire a mechanic — a searchable
## cart, a well that yields water — it will be an archetype component, and the
## asset will not have to change at all.
static func _register_human_traces() -> void:
	var wall := _natural(
		&"ruin_wall", "Обломки стен", &"world_props", "ruin_wall.tscn",
		Vector3(4.2, 1.7, 1.7),
		"Куски кладки и обломок колонны. Ставится группами на ровных площадках: одна стена — это мусор, три — бывшее поселение.",
		[
			{
				"name": "stone_color", "label": "Цвет кладки", "type": "color",
				"default": Color("a29d92"), "vary": 0.3,
				"bind": [{"node": "Stone", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_column", "label": "Колонна", "type": "bool",
				"default": true, "vary": 0.5,
				"bind": [{"node": "Stone/Column", "prop": "visible"}],
			},
			{
				"name": "has_rubble", "label": "Осыпь у основания", "type": "bool",
				"default": true, "vary": 0.75,
				"bind": [{"node": "Rubble", "prop": "visible"}],
			},
		]
	)
	wall.tags = [&"ruin", &"stone", &"obstacle"]
	wall.collision_policy = WorldAssetDef.COLLISION_SCENE
	wall.blocking_navigation = true
	wall.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_GENTLE
	)
	wall.placement.footprint_cells = Vector2i(3, 2)
	_scalable(wall, 0.8, 1.35)

	var menhir := _natural(
		&"menhir", "Менгир", &"world_props", "menhir.tscn", Vector3(1.3, 2.65, 1.0),
		"Одиночный камень на возвышенности. Метка точки интереса: его видно издалека, и он ничего не делает.",
		[
			{
				"name": "stone_color", "label": "Цвет камня", "type": "color",
				"default": Color("7b7a76"), "vary": 0.3,
				"bind": [{"node": "Stone", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "stone_height", "label": "Высота", "type": "float",
				"min": 0.7, "max": 1.4, "step": 0.05, "default": 1.0, "vary": 0.3,
				"bind": [{"node": "Stone", "prop": WorldAssetDef.PROP_SCALE_Y}],
			},
			{
				"name": "has_carvings", "label": "Резьба", "type": "bool",
				"default": false, "vary": 0.4,
				"bind": [{"node": "Carvings", "prop": "visible"}],
			},
		]
	)
	menhir.tags = [&"ruin", &"stone", &"landmark"]
	menhir.collision_policy = WorldAssetDef.COLLISION_SCENE
	menhir.blocking_navigation = true
	_scalable(menhir, 0.8, 1.5)

	var bones := _natural(
		&"bones", "Кости", &"world_props", "bones.tscn", Vector3(1.65, 0.4, 1.0),
		"Череп и рассыпанный скелет. Пустыня, тундра и окрестности руин: там, где никто не убрал.",
		[
			{
				"name": "bone_color", "label": "Цвет кости", "type": "color",
				"default": Color("d9d4c4"), "vary": 0.25,
				"bind": [
					{"node": "Skull", "prop": WorldAssetDef.PROP_ALBEDO},
					{"node": "Skeleton", "prop": WorldAssetDef.PROP_ALBEDO},
				],
			},
			{
				"name": "has_skull", "label": "Череп", "type": "bool",
				"default": true, "vary": 0.75,
				"bind": [{"node": "Skull", "prop": "visible"}],
			},
		]
	)
	bones.tags = [&"ruin", &"bones", &"desert"]
	_scalable(bones, 0.8, 1.3)

	var cart := _natural(
		&"abandoned_cart", "Брошенная телега", &"world_props", "abandoned_cart.tscn",
		Vector3(2.9, 1.5, 1.6),
		"Телега со слетевшим колесом. Ставится у старых дорог и переправ — там, где ломаются на самом деле.",
		[
			{
				"name": "wood_color", "label": "Цвет дерева", "type": "color",
				"default": Color("6d5339"), "vary": 0.3,
				"bind": [{"node": "Frame", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_cargo", "label": "Груз", "type": "bool",
				"default": false, "vary": 0.45,
				"bind": [{"node": "Cargo", "prop": "visible"}],
			},
		]
	)
	cart.tags = [&"ruin", &"wood", &"road"]
	cart.collision_policy = WorldAssetDef.COLLISION_SCENE
	cart.blocking_navigation = true
	cart.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_MODERATE
	)
	cart.placement.footprint_cells = Vector2i(2, 2)
	_scalable(cart, 0.9, 1.15)

	var crates := _natural(
		&"crate_pile", "Бочки и ящики", &"world_props", "crate_pile.tscn",
		Vector3(2.0, 1.2, 1.4),
		"Сваленная тара. Стоит кластерами у руин: одна бочка посреди поля не рассказывает ничего.",
		[
			{
				"name": "wood_color", "label": "Цвет дерева", "type": "color",
				"default": Color("7b6043"), "vary": 0.35,
				"bind": [
					{"node": "Crates", "prop": WorldAssetDef.PROP_ALBEDO},
					{"node": "Barrels", "prop": WorldAssetDef.PROP_ALBEDO},
				],
			},
			{
				"name": "has_crates", "label": "Ящики", "type": "bool",
				"default": true, "vary": 0.85,
				"bind": [{"node": "Crates", "prop": "visible"}],
			},
			{
				"name": "has_barrels", "label": "Бочки", "type": "bool",
				"default": true, "vary": 0.6,
				"bind": [{"node": "Barrels", "prop": "visible"}],
			},
		]
	)
	crates.tags = [&"ruin", &"wood", &"storage"]
	crates.collision_policy = WorldAssetDef.COLLISION_SCENE
	crates.blocking_navigation = true
	crates.scope = WorldAssetDef.SCOPE_BOTH
	crates.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_GENTLE
	)
	crates.placement.footprint_cells = Vector2i(2, 2)
	_scalable(crates, 0.85, 1.2)

	var well := _natural(
		&"well", "Колодец", &"world_props", "well.tscn", Vector3(1.8, 2.6, 1.8),
		"Каменное кольцо с воротом. Центр бывшего поселения: вокруг него и раскладываются руины.",
		[
			{
				"name": "stone_color", "label": "Цвет камня", "type": "color",
				"default": Color("92908a"), "vary": 0.25,
				"bind": [{"node": "Stone", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_roof", "label": "Навес", "type": "bool", "default": true,
				"bind": [
					{"node": "Roof", "prop": "visible"},
					{"node": "Timber", "prop": "visible"},
				],
			},
			{
				"name": "has_bucket", "label": "Ведро", "type": "bool",
				"default": true, "vary": 0.5,
				"bind": [{"node": "Bucket", "prop": "visible"}],
			},
		]
	)
	well.tags = [&"ruin", &"stone", &"town", &"landmark"]
	well.collision_policy = WorldAssetDef.COLLISION_SCENE
	well.blocking_navigation = true
	well.scope = WorldAssetDef.SCOPE_BOTH
	well.scale_mode = WorldAssetDef.SCALE_LOCKED
	well.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_GENTLE
	)
	well.placement.footprint_cells = Vector2i(2, 2)

	var signpost := _natural(
		&"signpost", "Путевой указатель", &"world_props", "signpost.tscn",
		Vector3(1.8, 2.05, 0.9),
		"Столб со стрелками на перекрёстке маршрутов. Надпись — авторская: указатель без имени места бесполезен.",
		[
			{
				"name": "sign_text", "label": "Надпись", "type": "string", "default": "Тракт",
				"bind": [{"node": "Boards/BoardUpperLabel", "prop": "text"}],
			},
			{
				"name": "board_color", "label": "Цвет досок", "type": "color",
				"default": Color("8a6f51"), "vary": 0.25,
				"bind": [{"node": "Boards", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_second_board", "label": "Вторая стрелка", "type": "bool",
				"default": true, "vary": 0.6,
				"bind": [
					{"node": "Boards/BoardLower", "prop": "visible"},
					{"node": "Boards/BoardLowerPoint", "prop": "visible"},
				],
			},
		]
	)
	signpost.tags = [&"sign", &"road", &"town"]
	signpost.collision_policy = WorldAssetDef.COLLISION_SCENE
	signpost.scope = WorldAssetDef.SCOPE_BOTH
	signpost.scale_mode = WorldAssetDef.SCALE_LOCKED
	signpost.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND], SlopeCatalog.CLASS_MODERATE
	)

	var boat := _natural(
		&"sunken_boat", "Затонувшая лодка", &"world_props", "sunken_boat.tscn",
		Vector3(4.1, 1.8, 1.2),
		"Полузатопленный корпус со сломанной мачтой. Как и камыш, объявляет воду обязательной.",
		[
			{
				"name": "wood_color", "label": "Цвет дерева", "type": "color",
				"default": Color("5a4c3d"), "vary": 0.3,
				"bind": [{"node": "Hull", "prop": WorldAssetDef.PROP_ALBEDO}],
			},
			{
				"name": "has_mast", "label": "Мачта", "type": "bool",
				"default": true, "vary": 0.6,
				"bind": [{"node": "Mast", "prop": "visible"}],
			},
		]
	)
	boat.tags = [&"ruin", &"wood", &"water"]
	boat.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_SHALLOW, AssetPlacementPolicy.SURFACE_WATER],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_REQUIRE
	)
	boat.placement.align_to_normal = AssetPlacementPolicy.ALIGN_NONE
	boat.placement.vertical_offset = -0.15
	boat.placement.footprint_cells = Vector2i(3, 2)
	_scalable(boat, 0.85, 1.25)


## Weather-driven particle effects. Like the fireflies they own no gameplay and
## carry no appearance controls: what a plume of smoke does is decided by the
## published `EnvironmentSnapshot`, not by a knob in the inspector.
static func _register_ambient_effects() -> void:
	var vent := _ambient_effect(
		&"smoke_vent", "Дым из расщелины", "smoke_vent_effect.tscn",
		Vector3(2.5, 6.0, 2.5),
		"Столб дыма с редкими искрами. Вулканические зоны; ветер сносит его вместе со всем остальным.",
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE],
		SlopeCatalog.CLASS_CLIFF
	)
	vent.tags = [&"ambient", &"smoke", &"volcanic"]

	var mist := _ambient_effect(
		&"waterfall_mist", "Брызги у порогов", "waterfall_mist_effect.tscn",
		Vector3(3.0, 3.5, 2.0),
		"Водяная пыль и брызги на перепаде русла. Ставится у порога, а не по всей реке.",
		[
			AssetPlacementPolicy.SURFACE_SHALLOW,
			AssetPlacementPolicy.SURFACE_WATER,
			AssetPlacementPolicy.SURFACE_GROUND,
		],
		SlopeCatalog.CLASS_CLIFF,
		AssetPlacementPolicy.SUBMERGED_ALLOW
	)
	mist.tags = [&"ambient", &"water"]

	var devil := _ambient_effect(
		&"dust_devil", "Пыльный вихрь", "dust_devil_effect.tscn",
		Vector3(2.5, 7.0, 2.5),
		"Вихрь песка на открытом месте. Сам гаснет в дождь, ночью и в безветрие — условия объявлены в сцене.",
		[AssetPlacementPolicy.SURFACE_GROUND],
		SlopeCatalog.CLASS_MODERATE
	)
	devil.tags = [&"ambient", &"desert", &"wind"]


## Ambient effects live with the other effects rather than in the asset folder:
## the catalog references scenes, it does not have to own every file.
static func _ambient_effect(
	id: StringName,
	name: String,
	scene_file: String,
	size_m: Vector3,
	description: String,
	surfaces: Array[StringName],
	max_slope_class: int,
	submerged: StringName = AssetPlacementPolicy.SUBMERGED_FORBID
) -> WorldAssetDef:
	var asset := WorldAssetDef.new(
		id, name, &"ambient", &"world",
		"res://game/features/world/presentation/ambient/".path_join(scene_file),
		Vector3i.ONE, 1.0, [], size_m, description
	)
	asset.rotation_axes = ["y"]
	asset.scope = WorldAssetDef.SCOPE_MAP
	asset.placement = AssetPlacementPolicy.of_surfaces(surfaces, max_slope_class, submerged)
	_register(asset)
	return asset


## Colour and size knobs shared by everything that has foliage over a woody part.
## `crown_size` is a control rather than the record's transform scale on purpose:
## the object's own footprint must not grow with its crown, or a wide tree would
## start refusing the cell it fits in.
##
## `snow_node` is empty for plants that have no snow cap authored. A control whose
## bind target does not exist would warn on every instantiation, and the warning
## would be right: the declaration, not the scene, would be the lie.
static func _foliage_controls(
	foliage_node: StringName,
	wood_node: StringName,
	foliage_color: Color,
	wood_color: Color,
	snow_node: String = "Snow"
) -> Array[Dictionary]:
	var controls: Array[Dictionary] = [
		{
			"name": "crown_color", "label": "Цвет листвы", "type": "color",
			"default": foliage_color, "vary": 0.55,
			"bind": [{"node": String(foliage_node), "prop": WorldAssetDef.PROP_ALBEDO}],
		},
		{
			"name": "trunk_color", "label": "Цвет древесины", "type": "color",
			"default": wood_color, "vary": 0.3,
			"bind": [{"node": String(wood_node), "prop": WorldAssetDef.PROP_ALBEDO}],
		},
		{
			"name": "crown_size", "label": "Размер кроны", "type": "float",
			"min": 0.7, "max": 1.35, "step": 0.05, "default": 1.0, "vary": 0.2,
			"bind": [{"node": String(foliage_node), "prop": WorldAssetDef.PROP_SCALE}],
		},
	]
	if not snow_node.is_empty():
		controls.append({
			"name": "has_snow", "label": "Снег", "type": "bool", "default": false,
			"bind": [{"node": snow_node, "prop": "visible"}],
		})
	return controls


static func _foliage_states(summer: Color, winter: Color, with_snow: bool = true) -> Dictionary:
	var states := {
		"summer": {"crown_color": summer.to_html(false)},
		"autumn": {"crown_color": "c07a2c"},
		"withered": {"crown_color": "6b4c2a"},
		"winter": {"crown_color": winter.to_html(false)},
	}
	if with_snow:
		for state_id: String in states:
			(states[state_id] as Dictionary)["has_snow"] = state_id == "winter"
	return states


static func _natural(
	id: StringName,
	name: String,
	category: StringName,
	scene_file: String,
	size_m: Vector3,
	description: String,
	controls: Array[Dictionary]
) -> WorldAssetDef:
	var asset := WorldAssetDef.new(
		id, name, category, &"world", SCENE_DIR.path_join(scene_file),
		Vector3i.ONE, 1.0, controls, size_m, description
	)
	# Yaw only: a tree tilted onto its side is a bug, not a variation. The ground
	# tilt these objects do take comes from the placement policy's normal
	# alignment, which the author does not hand-author per instance.
	asset.rotation_axes = ["y"]
	asset.collision_policy = WorldAssetDef.COLLISION_NONE
	asset.placement = AssetPlacementPolicy.of_surfaces(
		[AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE],
		SlopeCatalog.CLASS_MODERATE
	)
	# Природа — это то, что ставят помногу: кистью-разбросом (§9.2) и стадией
	# растительности генератора. Костёр, телега и колодец разброса не получают, и
	# это не забывчивость — засаженная кострами поляна не бывает нужна никому.
	#
	# Интервал берётся от габарита самого объекта: два дуба не растут вплотную, а
	# мох стелется сплошь, и оба числа уже сказаны размером ассета.
	asset.placement.scatter_allowed = true
	asset.placement.scatter_min_spacing_m = maxf(size_m.x, size_m.z) * 0.75
	_register(asset)
	return asset


## Free-scale range for natural objects. Two firs of identical height read as
## copy-paste, and clamping the range is what keeps "variation" from turning into
## a bonsai next to a giant.
static func _scalable(asset: WorldAssetDef, minimum: float, maximum: float) -> void:
	asset.scale_mode = WorldAssetDef.SCALE_FREE_UNIFORM
	asset.allowed_scales = [minimum, maximum]


static func _register(asset: WorldAssetDef) -> void:
	asset.group = group_of_category(asset.category)
	_assets[asset.id] = asset
