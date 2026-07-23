class_name SettlementUIAttacher
extends RefCounted

const CampfireMenuControllerScript = preload("res://game/features/settlement/presentation/campfire_menu_controller.gd")
const WorkforceMenuControllerScript = preload("res://game/features/decision/presentation/workforce_menu_controller.gd")
const ResearchMenuControllerScript = preload("res://game/features/settlement/presentation/research_menu_controller.gd")
const SchoolMenuControllerScript = preload("res://game/features/buildings/presentation/school_menu_controller.gd")
const EntranceMenuControllerScript = preload("res://game/features/buildings/presentation/entrance_menu_controller.gd")
const HouseMenuControllerScript = preload("res://game/features/buildings/presentation/house_menu_controller.gd")
const PocketTakeMenuControllerScript = preload("res://game/features/citizens/presentation/pocket_take_menu_controller.gd")
const MarketMenuControllerScript = preload("res://game/features/logistics/presentation/market_menu_controller.gd")
const WarehouseMenuControllerScript = preload("res://game/features/logistics/presentation/warehouse_menu_controller.gd")
const BuildingMenuControllerScript = preload("res://game/features/buildings/presentation/building_menu_controller.gd")

var campfire_menu_controller: RefCounted
var workforce_menu_controller: RefCounted
var research_menu_controller: RefCounted
var school_menu_controller: RefCounted
var entrance_menu_controller: RefCounted
var house_menu_controller: RefCounted
var pocket_take_menu_controller: RefCounted
var market_menu_controller: RefCounted
var warehouse_menu_controller: RefCounted
var building_menu_controller: RefCounted

func create_all_controllers() -> void:
	campfire_menu_controller = CampfireMenuControllerScript.new()
	workforce_menu_controller = WorkforceMenuControllerScript.new()
	research_menu_controller = ResearchMenuControllerScript.new()
	school_menu_controller = SchoolMenuControllerScript.new()
	entrance_menu_controller = EntranceMenuControllerScript.new()
	house_menu_controller = HouseMenuControllerScript.new()
	pocket_take_menu_controller = PocketTakeMenuControllerScript.new()
	market_menu_controller = MarketMenuControllerScript.new()
	warehouse_menu_controller = WarehouseMenuControllerScript.new()
	building_menu_controller = BuildingMenuControllerScript.new()

func configure_all(game: Node3D) -> void:
	if campfire_menu_controller != null: campfire_menu_controller.configure(game)
	if workforce_menu_controller != null: workforce_menu_controller.configure(game)
	if research_menu_controller != null: research_menu_controller.configure(game)
	if school_menu_controller != null: school_menu_controller.configure(game)
	if entrance_menu_controller != null: entrance_menu_controller.configure(game)
	if house_menu_controller != null: house_menu_controller.configure(game)
	if pocket_take_menu_controller != null: pocket_take_menu_controller.configure(game)
	if market_menu_controller != null: market_menu_controller.configure(game)
	if warehouse_menu_controller != null: warehouse_menu_controller.configure(game)
	if building_menu_controller != null: building_menu_controller.configure(game)

