class_name WorldResourceState
extends RefCounted

## Serializable mutable state for natural resources. It deliberately stores
## stable cells and values only; Node3D references stay in presentation.

var grass_sources: Array = []
var forage_cells: Array[Vector2i] = []
var forage_respawns: Array = []
var rabbits: Array = []
var rabbit_respawns: Array = []


func capture(
	grass: Dictionary,
	forage: Dictionary,
	forage_respawn_at: Dictionary,
	rabbit_sources: Dictionary,
	rabbit_respawn_at: Dictionary
) -> void:
	grass_sources.clear()
	forage_cells.clear()
	forage_respawns.clear()
	rabbits.clear()
	rabbit_respawns.clear()
	for cell: Vector2i in grass:
		var source: Variant = grass[cell]
		grass_sources.append({"cell": _cell_to_dict(cell), "remaining": int(source.remaining), "initial": int(source.initial)})
	for cell: Vector2i in forage:
		forage_cells.append(cell)
	for cell: Vector2i in forage_respawn_at:
		forage_respawns.append({"cell": _cell_to_dict(cell), "at": float(forage_respawn_at[cell])})
	for cell: Vector2i in rabbit_sources:
		var rabbit: Variant = rabbit_sources[cell]
		if not is_instance_valid(rabbit.node):
			continue
		rabbits.append({
			"cell": _cell_to_dict(cell),
			"position": _vector_to_dict(rabbit.node.global_position),
			"direction": _vector_to_dict(rabbit.direction),
		})
	for cell: Vector2i in rabbit_respawn_at:
		rabbit_respawns.append({"cell": _cell_to_dict(cell), "at": float(rabbit_respawn_at[cell])})


func to_save_dict() -> Dictionary:
	var forage: Array[Dictionary] = []
	for cell in forage_cells:
		forage.append(_cell_to_dict(cell))
	return {
		"grass_sources": grass_sources.duplicate(true),
		"forage_cells": forage,
		"forage_respawns": forage_respawns.duplicate(true),
		"rabbits": rabbits.duplicate(true),
		"rabbit_respawns": rabbit_respawns.duplicate(true),
	}


func load_from_save_dict(data: Dictionary) -> void:
	grass_sources = (data.get("grass_sources", []) as Array).duplicate(true)
	forage_cells.clear()
	for raw_cell in data.get("forage_cells", []):
		if raw_cell is Dictionary:
			forage_cells.append(_dict_to_cell(raw_cell))
	forage_respawns = (data.get("forage_respawns", []) as Array).duplicate(true)
	rabbits = (data.get("rabbits", []) as Array).duplicate(true)
	rabbit_respawns = (data.get("rabbit_respawns", []) as Array).duplicate(true)


static func _cell_to_dict(cell: Vector2i) -> Dictionary:
	return {"x": cell.x, "y": cell.y}


static func _dict_to_cell(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))


static func _vector_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


static func _dict_to_vector(data: Dictionary) -> Vector3:
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
