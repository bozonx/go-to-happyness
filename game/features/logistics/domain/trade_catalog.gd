class_name TradeCatalog
extends RefCounted

## Static trade item definitions per market type and era.
## Business rules for what each market buys, sells, and what courier equipment
## is available. These are domain rules, not presentation formatting.

const SettlementStateScript = preload("res://game/features/settlement/domain/settlement_state.gd")
const ResourceIds = preload("res://game/features/settlement/domain/resource_ids.gd")


static func sell_items_for(market_type: String) -> Array:
	var items := [[ResourceIds.GOODS, 5]]
	if market_type in ["earth_market", "clay_market", "wood_market", "stone_market", "brick_market"]:
		items.append([ResourceIds.SOIL, 1])
	if market_type in ["clay_market", "wood_market", "stone_market", "brick_market"]:
		items.append([ResourceIds.CLAY, 2])
	if market_type in ["wood_market", "stone_market", "brick_market"]:
		items.append([ResourceIds.WOOD, 2])
		items.append([ResourceIds.BOARDS, 3])
	if market_type in ["stone_market", "brick_market"]:
		items.append([ResourceIds.STONE, 3])
	if market_type == "brick_market":
		items.append([ResourceIds.BRICKS, 4])
	return items


static func buy_items_for(market_type: String) -> Array:
	var items: Array = []
	if market_type in ["straw_trade_tent", "tarp_trade_tent"]:
		items.append(["axe", 15])
		items.append(["hand_saw", 15])
		items.append(["shovel", 15])
		items.append(["bucket", 15])
		items.append([ResourceIds.TARP, 8])
	elif market_type in ["earth_market", "clay_market"]:
		items.append(["hoe", 18])
	elif market_type in ["wood_market", "stone_market", "brick_market"]:
		items.append(["pickaxe", 25])
	return items


static func equipment_offers_for(era: int) -> Array[Array]:
	var offers: Array[Array] = []
	if era == SettlementStateScript.Era.TENT:
		offers.append(["simple_backpack", 12])
	elif era >= SettlementStateScript.Era.CLAY:
		offers.append(["reinforced_backpack", 22])
		offers.append(["bicycle", 30])
		if era >= SettlementStateScript.Era.WOOD:
			offers.append(["cargo_backpack", 36])
			offers.append(["bicycle_trailer", 48])
	return offers
