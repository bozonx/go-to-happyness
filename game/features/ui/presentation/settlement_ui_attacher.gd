class_name SettlementUIAttacher
extends RefCounted


var campfire_menu_controller: CampfireMenuController
var workforce_menu_controller: WorkforceMenuController
var research_menu_controller: ResearchMenuController
var school_menu_controller: SchoolMenuController
var entrance_menu_controller: EntranceMenuController
var house_menu_controller: HouseMenuController
var pocket_take_menu_controller: PocketTakeMenuController
var market_menu_controller: MarketMenuController
var warehouse_menu_controller: WarehouseMenuController
var building_menu_controller: BuildingMenuController

func create_all_controllers() -> void:
	campfire_menu_controller = CampfireMenuController.new()
	workforce_menu_controller = WorkforceMenuController.new()
	research_menu_controller = ResearchMenuController.new()
	school_menu_controller = SchoolMenuController.new()
	entrance_menu_controller = EntranceMenuController.new()
	house_menu_controller = HouseMenuController.new()
	pocket_take_menu_controller = PocketTakeMenuController.new()
	market_menu_controller = MarketMenuController.new()
	warehouse_menu_controller = WarehouseMenuController.new()
	building_menu_controller = BuildingMenuController.new()

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

