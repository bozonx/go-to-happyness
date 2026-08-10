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
	# so neither a collider nor navigation blocking applies; the weather controller
	# reaches each instance through `WorldSetup.fireflies`. The scene stays with the
	# weather feature that drives it — the catalog references assets, it does not
	# have to own every file.
	var fireflies := WorldAssetDef.new(
		&"fireflies", "Светлячки", &"ambient", &"world",
		"res://game/features/world/presentation/fireflies_effect.tscn",
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
