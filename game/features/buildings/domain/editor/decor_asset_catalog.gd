class_name DecorAssetCatalog
extends RefCounted

## Catalog of decor asset definitions and category definitions.

const DecorAssetDefScript = preload("res://game/features/buildings/domain/editor/decor_asset_def.gd")

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

static var _builtin_assets: Dictionary = {}


static func get_all_assets() -> Array[DecorAssetDefScript]:
	_ensure_catalog()
	var list: Array[DecorAssetDefScript] = []
	for asset: DecorAssetDefScript in _builtin_assets.values():
		list.append(asset)
	return list


static func get_assets_by_category(category: StringName) -> Array[DecorAssetDefScript]:
	_ensure_catalog()
	var list: Array[DecorAssetDefScript] = []
	for asset: DecorAssetDefScript in _builtin_assets.values():
		if asset.category == category:
			list.append(asset)
	return list


static func get_asset(id: StringName) -> DecorAssetDefScript:
	_ensure_catalog()
	return _builtin_assets.get(id, null)


static func _ensure_catalog() -> void:
	if not _builtin_assets.is_empty():
		return

	_register_asset(DecorAssetDefScript.new(
		&"campfire",
		"Костёр",
		&"camping",
		&"outdoor",
		"res://game/features/buildings/presentation/decor/scenes/campfire.tscn",
		Vector3i(1, 1, 1),
		0.5,
		[
			{"name": "is_lit", "label": "Горит", "type": "bool", "default": true},
			{"name": "light_energy", "label": "Яркость света", "type": "float", "min": 0.0, "max": 5.0, "step": 0.1, "default": 1.5},
			{"name": "light_color", "label": "Цвет света", "type": "color", "default": Color("ffaa44")},
		]
	))

	_register_asset(DecorAssetDefScript.new(
		&"cooking_campfire",
		"Костёр для готовки",
		&"camping",
		&"outdoor",
		"res://game/features/buildings/presentation/decor/scenes/cooking_campfire.tscn",
		Vector3i(1, 1, 1),
		0.5,
		[
			{"name": "is_lit", "label": "Горит", "type": "bool", "default": true},
			{"name": "light_energy", "label": "Яркость света", "type": "float", "min": 0.0, "max": 5.0, "step": 0.1, "default": 1.5},
			{"name": "has_pot", "label": "Котел над огнем", "type": "bool", "default": true},
		]
	))

	_register_asset(DecorAssetDefScript.new(
		&"entrance_sign",
		"Въездной знак",
		&"town",
		&"outdoor",
		"res://game/features/buildings/presentation/decor/scenes/entrance_sign.tscn",
		Vector3i(2, 2, 1),
		0.5,
		[
			{"name": "sign_text", "label": "Текст на знаке", "type": "string", "default": "Happyness"},
			{"name": "has_lantern", "label": "Фонарь", "type": "bool", "default": true},
		]
	))


static func _register_asset(asset: DecorAssetDefScript) -> void:
	_builtin_assets[asset.id] = asset
