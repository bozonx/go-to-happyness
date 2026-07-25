class_name DecorAssetCatalog
extends RefCounted

## Catalog of decor asset definitions and their category taxonomy
## (design_docs/content/modular_building_editor.md §3.3).
##
## Assets come from three sources, merged by id (later sources win):
##   1. the built-in definitions below;
##   2. `DecorAssetDef` resources under `res://game/features/buildings/data/decor`;
##   3. player-authored resources under `user://custom_decor`.

const DecorAssetDefScript = preload("res://game/features/buildings/domain/editor/decor_asset_def.gd")

const BUILTIN_ASSET_DIR := "res://game/features/buildings/data/decor"
const CUSTOM_ASSET_DIR := "user://custom_decor"
const SCENE_DIR := "res://game/features/buildings/presentation/decor/scenes"

const GROUPS: Dictionary = {
	&"outdoor": "Экстерьер",
	&"interior": "Интерьер",
	&"architecture": "Архитектура",
}

const CATEGORIES: Dictionary = {
	# Outdoor
	&"camping": {"name": "Кэмпинг", "group": &"outdoor"},
	&"town": {"name": "Город / Знаки", "group": &"outdoor"},
	&"nature": {"name": "Природа / Сад", "group": &"outdoor"},
	# Interior
	&"furniture": {"name": "Мебель", "group": &"interior"},
	&"lighting": {"name": "Освещение", "group": &"interior"},
	&"utensils": {"name": "Утварь / Быт", "group": &"interior"},
	&"cozy": {"name": "Уют / Текстиль", "group": &"interior"},
	# Architecture
	&"structural_decor": {"name": "Декор конструкций", "group": &"architecture"},
	&"roof_decor": {"name": "Декор крыш", "group": &"architecture"},
	&"wall_decor": {"name": "Настенный декор", "group": &"architecture"},
}

static var _assets: Dictionary = {}


static func get_all_assets() -> Array[DecorAssetDefScript]:
	_ensure_catalog()
	var list: Array[DecorAssetDefScript] = []
	for asset: DecorAssetDefScript in _assets.values():
		list.append(asset)
	return list


static func get_assets_by_category(category: StringName) -> Array[DecorAssetDefScript]:
	_ensure_catalog()
	var list: Array[DecorAssetDefScript] = []
	for asset: DecorAssetDefScript in _assets.values():
		if asset.category == category:
			list.append(asset)
	list.sort_custom(func(a: DecorAssetDefScript, b: DecorAssetDefScript) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0)
	return list


static func get_asset(id: StringName) -> DecorAssetDefScript:
	_ensure_catalog()
	return _assets.get(id, null)


static func has_asset(id: StringName) -> bool:
	_ensure_catalog()
	return _assets.has(id)


## How many assets each category holds — the editor greys out empty categories
## instead of dropping the author into a blank list.
static func category_counts() -> Dictionary:
	_ensure_catalog()
	var counts: Dictionary = {}
	for category_id in CATEGORIES.keys():
		counts[category_id] = 0
	for asset: DecorAssetDefScript in _assets.values():
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
		var asset := load(dir_path.path_join(clean_name)) as DecorAssetDefScript
		if asset == null or asset.id == &"":
			push_warning("DecorAssetCatalog: skipped invalid asset %s" % clean_name)
			continue
		if not CATEGORIES.has(asset.category):
			push_warning("DecorAssetCatalog: asset %s has unknown category %s" % [asset.id, asset.category])
			continue
		if not ResourceLoader.exists(asset.scene_path):
			push_warning("DecorAssetCatalog: asset %s points at a missing scene %s" % [asset.id, asset.scene_path])
			continue
		asset.group = group_of_category(asset.category)
		_assets[asset.id] = asset


static func _register_builtin_assets() -> void:
	_register(DecorAssetDefScript.new(
		&"campfire",
		"Костёр",
		&"camping",
		&"outdoor",
		SCENE_DIR.path_join("campfire.tscn"),
		Vector3i(1, 1, 1),
		0.5,
		[
			{
				"name": "is_lit", "label": "Горит", "type": "bool", "default": true,
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
					{"node": "Fire/FlameCore", "prop": DecorAssetDefScript.PROP_ALBEDO},
				],
			},
			{
				"name": "flame_height", "label": "Высота пламени", "type": "float",
				"min": 0.4, "max": 2.0, "step": 0.1, "default": 1.0,
				"bind": [{"node": "Fire", "prop": DecorAssetDefScript.PROP_SCALE_Y}],
			},
		],
		Vector3(1.3, 0.9, 1.3),
		"Кольцо камней, сложенные брёвна, живое пламя с искрами."
	))

	_register(DecorAssetDefScript.new(
		&"cooking_campfire",
		"Костёр для готовки",
		&"camping",
		&"outdoor",
		SCENE_DIR.path_join("cooking_campfire.tscn"),
		Vector3i(2, 2, 2),
		0.5,
		[
			{
				"name": "is_lit", "label": "Горит", "type": "bool", "default": true,
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

	_register(DecorAssetDefScript.new(
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
				"bind": [{"node": "Board/BoardMesh", "prop": DecorAssetDefScript.PROP_ALBEDO}],
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

	_register(DecorAssetDefScript.new(
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
					{"node": "Mast/Banner/BannerMesh", "prop": DecorAssetDefScript.PROP_ALBEDO},
					{"node": "Mast/Banner/BannerTail", "prop": DecorAssetDefScript.PROP_ALBEDO},
				],
			},
			{
				"name": "pole_height", "label": "Высота древка", "type": "float",
				"min": 0.6, "max": 2.0, "step": 0.05, "default": 1.0,
				"bind": [{"node": "Mast", "prop": DecorAssetDefScript.PROP_SCALE_Y}],
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


static func _register(asset: DecorAssetDefScript) -> void:
	asset.group = group_of_category(asset.category)
	_assets[asset.id] = asset
