class_name WorldAssetCatalog
extends RefCounted

## Catalog of world asset definitions and their category taxonomy
## (design_docs/engine/map_fill_mode.md §3, design_docs/engine/building_furnishing.md §5).
##
## The current vertical slice contains the built-in definitions below. Pack-owned
## asset definitions intentionally wait for their JSON format and first external
## consumer; there is no dead Resource-directory fallback or second loose-file
## source for editors to interpret differently.

const SCENE_DIR := "res://game/features/buildings/presentation/decor/scenes"

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
	_assets.clear()
	_ensure_catalog()


static func _ensure_catalog() -> void:
	if not _assets.is_empty():
		return
	_register_builtin_assets()


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


static func _register_natural_assets() -> void:
	for data in [
		[&"tree", "Дерево", &"vegetation", "res://game/features/world/presentation/tree.tscn", Vector3(2.0, 5.0, 2.0), true],
		[&"grass_source", "Трава", &"vegetation", "res://game/features/world/presentation/grass_source.tscn", Vector3(1.2, 0.6, 1.2), false],
		[&"forage_source", "Дикая пища", &"vegetation", "res://game/features/world/presentation/forage_source.tscn", Vector3(0.5, 0.5, 0.5), false],
		[&"rabbit", "Кролик", &"creatures", "res://game/features/world/presentation/rabbit.tscn", Vector3(0.5, 0.4, 0.5), false],
		# Fireflies are a non-physical ambient effect (a MultiMesh of glowing
		# points), so neither a collider nor navigation blocking applies; the
		# weather controller reaches each instance through `WorldSetup.fireflies`.
		[&"fireflies", "Светлячки", &"ambient", "res://game/features/world/presentation/fireflies_effect.tscn", Vector3(4.0, 3.0, 4.0), false],
	]:
		var asset := WorldAssetDef.new(data[0], data[1], data[2], &"world", data[3], Vector3i.ONE, 1.0, [], data[4])
		asset.scope = WorldAssetDef.SCOPE_MAP if data[0] in [&"rabbit", &"fireflies"] else WorldAssetDef.SCOPE_BOTH
		asset.rotation_axes = ["y"]
		# Only a scene that actually authors a physical body may claim scene
		# collision. Grass/forage interaction selectors are Area3D concerns added by
		# their owning module, and the current rabbit visual is not a physics actor.
		asset.collision_policy = WorldAssetDef.COLLISION_SCENE if data[0] == &"tree" else WorldAssetDef.COLLISION_NONE
		asset.blocking_navigation = bool(data[5])
		asset.placement = AssetPlacementPolicy.of_surfaces([AssetPlacementPolicy.SURFACE_GROUND, AssetPlacementPolicy.SURFACE_ICE], SlopeCatalog.CLASS_MODERATE)
		_register(asset)


static func _register(asset: WorldAssetDef) -> void:
	asset.group = group_of_category(asset.category)
	_assets[asset.id] = asset
