class_name FurnishingAssetCatalog
extends RefCounted

## Catalog of furnishing asset definitions and their category taxonomy
## (design_docs/content/building_furnishing.md §5).
##
## Assets come from three sources, merged by id (later sources win):
##   1. the built-in definitions below;
##   2. `FurnishingAssetDef` resources under `res://game/features/buildings/data/decor`;
##   3. player-authored resources under `user://custom_decor`.

const FurnishingAssetDefScript = preload("res://game/features/buildings/domain/editor/furnishing_asset_def.gd")
const BuildingMaterialCatalogScript = preload("res://game/features/buildings/domain/editor/building_material_catalog.gd")

const BUILTIN_ASSET_DIR := "res://game/features/buildings/data/decor"
const CUSTOM_ASSET_DIR := "user://custom_decor"
const SCENE_DIR := "res://game/features/buildings/presentation/decor/scenes"

const GROUPS: Dictionary = {
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

## Map old category ids to new ones for backward compatibility.
const MIGRATED_CATEGORIES: Dictionary = {
	&"furniture": &"tables_seating",
	&"lighting": &"lighting",
}

static var _assets: Dictionary = {}


static func get_all_assets() -> Array[FurnishingAssetDefScript]:
	_ensure_catalog()
	var list: Array[FurnishingAssetDefScript] = []
	for asset: FurnishingAssetDefScript in _assets.values():
		list.append(asset)
	return list


static func get_assets_by_category(category: StringName) -> Array[FurnishingAssetDefScript]:
	_ensure_catalog()
	var list: Array[FurnishingAssetDefScript] = []
	for asset: FurnishingAssetDefScript in _assets.values():
		if asset.category == category:
			list.append(asset)
	list.sort_custom(func(a: FurnishingAssetDefScript, b: FurnishingAssetDefScript) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return list


static func get_asset(id: StringName) -> FurnishingAssetDefScript:
	_ensure_catalog()
	return _assets.get(id, null)


static func has_asset(id: StringName) -> bool:
	_ensure_catalog()
	return _assets.has(id)


## Returns the migrated category for a legacy category id, or the original
## category if no migration is needed.
static func migrate_category(category_id: StringName) -> StringName:
	return MIGRATED_CATEGORIES.get(category_id, category_id)


## How many assets each category holds — the editor greys out empty categories
## instead of dropping the author into a blank list.
static func category_counts() -> Dictionary:
	_ensure_catalog()
	var counts: Dictionary = {}
	for category_id in CATEGORIES.keys():
		counts[category_id] = 0
	for asset: FurnishingAssetDefScript in _assets.values():
		counts[asset.category] = int(counts.get(asset.category, 0)) + 1
	return counts


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
static func first_populated_category(preferred: StringName = &"camping") -> StringName:
	var counts := category_counts()
	if int(counts.get(preferred, 0)) > 0:
		return preferred
	for category_id in CATEGORIES.keys():
		if int(counts.get(category_id, 0)) > 0:
			return category_id
	return preferred


## Filter assets by tag (design §5.2). Returns all assets if tag is empty.
static func get_assets_by_tag(tag: StringName) -> Array[FurnishingAssetDefScript]:
	_ensure_catalog()
	if tag == &"":
		return get_all_assets()
	var list: Array[FurnishingAssetDefScript] = []
	for asset: FurnishingAssetDefScript in _assets.values():
		if tag in asset.tags:
			list.append(asset)
	return list


## Filter assets by era (design §5.2). Returns all assets if era is empty.
## An asset is available when its `available_from_era` rank is at or below the
## selected era's rank — cumulative progression, not exact equality.
static func get_assets_by_era(era: StringName) -> Array[FurnishingAssetDefScript]:
	_ensure_catalog()
	if era == &"":
		return get_all_assets()
	var era_rank := BuildingMaterialCatalogScript.era_rank(era)
	var list: Array[FurnishingAssetDefScript] = []
	for asset: FurnishingAssetDefScript in _assets.values():
		if asset.available_from_era == &"":
			list.append(asset)
		elif BuildingMaterialCatalogScript.era_rank(asset.available_from_era) <= era_rank:
			list.append(asset)
	return list


## Combined filter for catalog UI (design §5.2).
## Empty / null filters are ignored.
static func filter_assets(
	p_category: StringName = &"",
	p_tag: StringName = &"",
	p_era: StringName = &""
) -> Array[FurnishingAssetDefScript]:
	_ensure_catalog()
	var list: Array[FurnishingAssetDefScript] = []
	for asset: FurnishingAssetDefScript in _assets.values():
		if p_category != &"" and asset.category != p_category:
			continue
		if p_tag != &"" and not (p_tag in asset.tags):
			continue
		if p_era != &"" and asset.available_from_era != &"":
			if BuildingMaterialCatalogScript.era_rank(asset.available_from_era) > BuildingMaterialCatalogScript.era_rank(p_era):
				continue
		list.append(asset)
	list.sort_custom(func(a: FurnishingAssetDefScript, b: FurnishingAssetDefScript) -> bool:
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
	_scan_directory(BUILTIN_ASSET_DIR)
	_scan_directory(CUSTOM_ASSET_DIR)


static func _scan_directory(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name in dir.get_files():
		# Exported projects append `.remap` to imported resources; accept both.
		var clean_name := file_name.trim_suffix(".remap")
		if not (clean_name.ends_with(".tres") or clean_name.ends_with(".res")):
			continue
		var asset := load(dir_path.path_join(clean_name)) as FurnishingAssetDefScript
		if asset == null or asset.id == &"":
			push_warning("FurnishingAssetCatalog: skipped invalid asset %s" % clean_name)
			continue
		# Migrate legacy category names so old custom assets still load.
		if MIGRATED_CATEGORIES.has(asset.category):
			asset.category = MIGRATED_CATEGORIES[asset.category]
		if not CATEGORIES.has(asset.category):
			push_warning("FurnishingAssetCatalog: asset %s has unknown category %s" % [asset.id, asset.category])
			continue
		if not ResourceLoader.exists(asset.scene_path):
			push_warning("FurnishingAssetCatalog: asset %s points at a missing scene %s" % [asset.id, asset.scene_path])
			continue
		asset.group = group_of_category(asset.category)
		_assets[asset.id] = asset


static func _register_builtin_assets() -> void:
	_register(FurnishingAssetDefScript.new(
		&"campfire",
		"Костёр",
		&"fires_stoves",
		&"lighting_heating",
		SCENE_DIR.path_join("campfire.tscn"),
		Vector3i(1, 1, 1),
		0.5,
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
					{"node": "Fire/FlameCore", "prop": FurnishingAssetDefScript.PROP_ALBEDO},
				],
			},
			{
				"name": "flame_height", "label": "Высота пламени", "type": "float",
				"min": 0.4, "max": 2.0, "step": 0.1, "default": 1.0,
				"bind": [{"node": "Fire", "prop": FurnishingAssetDefScript.PROP_SCALE_Y}],
			},
		],
		Vector3(1.3, 0.9, 1.3),
		"Кольцо камней, сложенные брёвна, живое пламя с искрами."
	))
	# Additional metadata for campfire
	var campfire := _assets[&"campfire"] as FurnishingAssetDefScript
	campfire.tags = [&"fire", &"light", &"cooking", &"outdoor"]
	campfire.available_from_era = &"tent"
	campfire.scale_mode = FurnishingAssetDefScript.SCALE_LOCKED
	campfire.collision_policy = FurnishingAssetDefScript.COLLISION_FOOTPRINT
	campfire.blocking_navigation = true
	campfire.supported_capabilities = [&"fire_source", &"cooking_station", &"light_source"]

	_register(FurnishingAssetDefScript.new(
		&"cooking_campfire",
		"Костёр для готовки",
		&"fires_stoves",
		&"lighting_heating",
		SCENE_DIR.path_join("cooking_campfire.tscn"),
		Vector3i(2, 2, 2),
		0.5,
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
	var cooking := _assets[&"cooking_campfire"] as FurnishingAssetDefScript
	cooking.tags = [&"fire", &"light", &"cooking", &"outdoor"]
	cooking.available_from_era = &"tent"
	cooking.scale_mode = FurnishingAssetDefScript.SCALE_LOCKED
	cooking.collision_policy = FurnishingAssetDefScript.COLLISION_FOOTPRINT
	cooking.blocking_navigation = true
	cooking.supported_capabilities = [&"fire_source", &"cooking_station", &"light_source"]

	_register(FurnishingAssetDefScript.new(
		&"entrance_sign",
		"Въездной знак",
		&"town",
		&"outdoor",
		SCENE_DIR.path_join("entrance_sign.tscn"),
		Vector3i(2, 2, 1),
		0.5,
		[
			{
				"name": "sign_text", "label": "Текст на знаке", "type": "string",
				"default": "Happyness",
				"bind": [{"node": "Board/SignLabel", "prop": "text"}],
			},
			{
				"name": "board_color", "label": "Цвет щита", "type": "color",
				"default": Color("8a6549"),
				"bind": [{"node": "Board/BoardMesh", "prop": FurnishingAssetDefScript.PROP_ALBEDO}],
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
	var sign := _assets[&"entrance_sign"] as FurnishingAssetDefScript
	sign.tags = [&"sign", &"town", &"light"]
	sign.available_from_era = &"tent"
	sign.scale_mode = FurnishingAssetDefScript.SCALE_LOCKED
	sign.collision_policy = FurnishingAssetDefScript.COLLISION_BOX
	sign.blocking_navigation = true
	sign.supported_capabilities = [&"light_source"]

	_register(FurnishingAssetDefScript.new(
		&"flag",
		"Флаг",
		&"town",
		&"outdoor",
		SCENE_DIR.path_join("flag.tscn"),
		Vector3i(1, 3, 1),
		0.5,
		[
			{
				"name": "banner_color", "label": "Цвет полотнища", "type": "color",
				"default": Color("d45448"),
				"bind": [
					{"node": "Mast/Banner/BannerMesh", "prop": FurnishingAssetDefScript.PROP_ALBEDO},
					{"node": "Mast/Banner/BannerTail", "prop": FurnishingAssetDefScript.PROP_ALBEDO},
				],
			},
			{
				"name": "pole_height", "label": "Высота древка", "type": "float",
				"min": 0.6, "max": 2.0, "step": 0.05, "default": 1.0,
				"bind": [{"node": "Mast", "prop": FurnishingAssetDefScript.PROP_SCALE_Y}],
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
	var flag := _assets[&"flag"] as FurnishingAssetDefScript
	flag.tags = [&"town", &"sign"]
	flag.available_from_era = &"tent"
	flag.scale_mode = FurnishingAssetDefScript.SCALE_UNIFORM_STEPS
	flag.allowed_scales = [0.5, 1.0, 2.0]
	flag.collision_policy = FurnishingAssetDefScript.COLLISION_BOX
	flag.blocking_navigation = true


static func _register(asset: FurnishingAssetDefScript) -> void:
	asset.group = group_of_category(asset.category)
	_assets[asset.id] = asset
