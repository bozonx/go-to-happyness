class_name MarketMenuController
extends RefCounted

const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")

var simulation: Node


func configure(next_simulation: Node) -> void:
	simulation = next_simulation


func show_market_menu() -> void:
	if simulation == null:
		return
	simulation.selected_builder = null
	simulation.build_menu.visible = false
	simulation.build_menu_is_global = false
	simulation.selection_marker.visible = false
	simulation.build_mode = ""
	simulation.market_menu.visible = true
	refresh_market_menu()


func refresh_market_menu() -> void:
	if simulation == null or simulation.selected_market == null or simulation.market_menu == null:
		return
	var market_type: String = simulation.selected_market.get_meta("building_type", "straw_trade_tent")
	var available_money: int = simulation._available_trade_money()
	var seller_ok: bool = simulation._is_seller_present_at(simulation.selected_market)

	var title_text := "%s Menu\nCoins: %d  Available: %d\nCompleted sales: %d" % [market_type.capitalize().replace("_", " "), simulation.settlement.money, available_money, simulation.settlement.trade_sales]
	if not seller_ok:
		title_text += "\nINACTIVE: Seller is missing!\n(Seller must be working at the market to trade)"

	var y_offset := 104.0 if not seller_ok else 80.0

	var raw_sell_items := [["goods", 5]]
	var raw_buy_items: Array = []

	if market_type in ["straw_trade_tent", "tarp_trade_tent"]:
		raw_buy_items.append(["axe", 15])
		raw_buy_items.append(["hand_saw", 15])
		raw_buy_items.append(["shovel", 15])
		raw_buy_items.append(["bucket", 15])
		raw_buy_items.append(["tarp", 8])
	elif market_type in ["earth_market", "clay_market"]:
		raw_buy_items.append(["hoe", 18])
	elif market_type in ["wood_market", "stone_market", "brick_market"]:
		raw_buy_items.append(["pickaxe", 25])

	if market_type in ["earth_market", "clay_market", "wood_market", "stone_market", "brick_market"]:
		raw_sell_items.append(["soil", 1])

	if market_type in ["clay_market", "wood_market", "stone_market", "brick_market"]:
		raw_sell_items.append(["clay", 2])

	if market_type in ["wood_market", "stone_market", "brick_market"]:
		raw_sell_items.append(["wood", 2])
		raw_sell_items.append(["boards", 3])

	if market_type in ["stone_market", "brick_market"]:
		raw_sell_items.append(["stone", 3])

	if market_type == "brick_market":
		raw_sell_items.append(["bricks", 4])

	var sell_items: Array[Dictionary] = []
	for item in raw_sell_items:
		var res: String = item[0]
		var price: int = item[1]
		var sellable: int = mini(5, simulation.settlement.amount(res))
		sell_items.append({
			"text": "Sell %d %s (+%d)  Stock: %d" % [sellable, res, price * sellable, simulation.settlement.amount(res)],
			"disabled": sellable <= 0 or not seller_ok,
			"tooltip": "Seller is missing" if not seller_ok else ("Nothing left to sell" if sellable <= 0 else "Sell up to five units from available stock"),
			"resource": res,
			"quantity": sellable,
			"price": price,
		})

	var buy_items: Array[Dictionary] = []
	for item in raw_buy_items:
		var tool_name: String = item[0]
		var price: int = item[1]
		var already_ordered: bool = simulation._trade_has_tool_order(tool_name)
		var owned: bool = bool(simulation.settlement.tools.get(tool_name, false))
		buy_items.append({
			"text": "Buy %s (%d Coins)" % [tool_name.replace("_", " "), price],
			"disabled": owned or already_ordered or available_money < price or not seller_ok,
			"tooltip": "Seller is missing" if not seller_ok else ("Already owned" if owned else ("Already ordered" if already_ordered else "Not enough available coins" if available_money < price else "")),
			"tool_id": tool_name,
			"price": price,
		})

	var state := {
		"title_text": title_text,
		"y_offset": y_offset,
		"sell_items": sell_items,
		"buy_items": buy_items,
	}

	var equipment_target = simulation.selected_builder if is_instance_valid(simulation.selected_builder) and simulation.selected_builder.is_courier() else null
	var raw_equipment_offers: Array[Array] = []
	if simulation.settlement.era == SettlementStateScript.Era.TENT:
		raw_equipment_offers.append(["simple_backpack", 12])
	elif simulation.settlement.era >= SettlementStateScript.Era.CLAY:
		raw_equipment_offers.append(["reinforced_backpack", 22])
		raw_equipment_offers.append(["bicycle", 30])
		if simulation.settlement.era >= SettlementStateScript.Era.WOOD:
			raw_equipment_offers.append(["cargo_backpack", 36])
			raw_equipment_offers.append(["bicycle_trailer", 48])
	if not raw_equipment_offers.is_empty():
		state["equipment_label"] = "Courier equipment: %s" % (equipment_target.role_label() if equipment_target != null else "select a courier")
		var equipment_offers: Array[Dictionary] = []
		for offer in raw_equipment_offers:
			var equipment_id: String = offer[0]
			var equipment_price: int = offer[1]
			equipment_offers.append({
				"text": "Buy %s (%d Coins)" % [equipment_id.replace("_", " "), equipment_price],
				"disabled": not seller_ok or equipment_target == null or equipment_target.courier_equipment == equipment_id or available_money < equipment_price,
				"tooltip": "Select a pinned courier first" if equipment_target == null else "",
				"courier": equipment_target,
				"equipment_id": equipment_id,
				"price": equipment_price,
			})
		state["equipment_offers"] = equipment_offers

	var room: int = maxi(0, simulation.settlement.storage_room_for("food") - simulation._trade_incoming_resource("food"))
	var buyable: int = mini(5, mini(room, available_money / simulation.FOOD_PURCHASE_PRICE))
	state["food_button"] = {
		"text": "Buy %d food (%d Coins)  Room: %d" % [buyable, buyable * simulation.FOOD_PURCHASE_PRICE, room],
		"disabled": buyable <= 0 or not seller_ok,
		"tooltip": "Seller is missing" if not seller_ok else ("No storage room or available coins" if buyable <= 0 else "Buy food for the settlement"),
		"quantity": buyable,
		"unit_price": simulation.FOOD_PURCHASE_PRICE,
	}

	simulation.market_menu.update_state(state)
