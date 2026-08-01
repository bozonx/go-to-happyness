class_name BlockTextureLibrary
extends RefCounted

## Albedo texture registry for building block materials.
##
## Mirrors the terrain system's approach (TerrainMaterialLibrary) but stays
## simpler: building blocks use individual StandardMaterial3D instances, not a
## shared shader + texture array, so each material maps to a single Texture2D.
##
## An empty path in AUTHORED_TEXTURE_PATHS means the texture is not drawn yet —
## the block falls back to its catalog colour. Dropping the PNG into the asset
## directory later lights up the material without touching this file, exactly
## like the terrain system's stage-1 placeholders.

## Where every authored block texture lives.
const ASSET_DIR := "res://game/features/buildings/presentation/editor/materials/textures/"

## Authored albedo textures keyed by material id. An empty string means the
## texture is not authored yet and the material uses its catalog colour instead.
const AUTHORED_TEXTURE_PATHS: Dictionary = {
	&"branches": "branches",
	&"tarp": "tarp",
	&"thatch": "thatch",
	&"earth_stone": "earth_stone",
	&"earth": "earth",
	&"adobe": "adobe",
	&"clay": "clay",
	&"logs": "logs",
	&"wood": "wood",
	&"stone_mortar": "stone_mortar",
	&"stone": "stone",
	&"brick_mortar": "brick_mortar",
	&"brick": "brick",
}

var _texture_cache: Dictionary = {}


func texture_for(material_id: StringName) -> Texture2D:
	if _texture_cache.has(material_id):
		return _texture_cache[material_id]
	var path := _authored_path(material_id)
	if path == "":
		_texture_cache[material_id] = null
		return null
	var texture := load(path) as Texture2D
	_texture_cache[material_id] = texture
	return texture


func has_texture(material_id: StringName) -> bool:
	return _authored_path(material_id) != ""


func _authored_path(material_id: StringName) -> String:
	var base_name: String = AUTHORED_TEXTURE_PATHS.get(material_id, "")
	if base_name == "":
		base_name = String(material_id)
	var path := ASSET_DIR + base_name + ".png"
	return path if ResourceLoader.exists(path) else ""
