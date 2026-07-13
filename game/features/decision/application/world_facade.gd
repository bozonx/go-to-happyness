class_name AIWorldFacade
extends RefCounted

## Read port between scene state and the pure decision model.


func capture(_sequence: int) -> WorldSnapshot:
	return WorldSnapshot.new()
