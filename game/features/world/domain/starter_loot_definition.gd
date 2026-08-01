class_name StarterLootDefinition
extends Resource

@export var cell: Vector2i = Vector2i.ZERO
@export var grass: int = 0
@export var branches: int = 0


func resources() -> Dictionary:
	var result: Dictionary = {}
	if grass > 0:
		result[&"grass"] = grass
	if branches > 0:
		result[&"branches"] = branches
	return result

