class_name BuildingSpatialRegistry
extends RefCounted

var warehouse_positions: Array[Vector3] = []
var sawmill_positions: Array[Vector3] = []
var farm_positions: Array[Vector3] = []
var builders_guild_positions: Array[Vector3] = []
var construction_company_positions: Array[Vector3] = []
var pond_positions: Array[Vector3] = []
var forager_positions: Array[Vector3] = []
var materials_yard_positions: Array[Vector3] = []
var school_positions: Array[Vector3] = []
var market_positions: Array[Vector3] = []
var craft_tent_positions: Array[Vector3] = []
var park_positions: Array[Vector3] = []
var leisure_positions: Array[Vector3] = []
var gathering_place_positions: Array[Vector3] = []
var factories: Array[Node3D] = []

func clear_all() -> void:
	warehouse_positions.clear()
	sawmill_positions.clear()
	farm_positions.clear()
	builders_guild_positions.clear()
	construction_company_positions.clear()
	pond_positions.clear()
	forager_positions.clear()
	materials_yard_positions.clear()
	school_positions.clear()
	market_positions.clear()
	craft_tent_positions.clear()
	park_positions.clear()
	leisure_positions.clear()
	gathering_place_positions.clear()
	factories.clear()
