class_name BuildingAvailabilityService
extends RefCounted

const REASON_OK := &"ok"
const REASON_LATER_ERA := &"later_era"
const REASON_LOCKED := &"locked"
const REASON_UPGRADE_ONLY := &"upgrade_only"
const REASON_NOT_ENOUGH_RESOURCES := &"not_enough_resources"
const REASON_EMPTY := &"empty"
const REASON_NO_FLAG := &"no_flag"
const REASON_NO_CAMPFIRE := &"no_campfire"

var settlement: SettlementState


func configure(next_settlement: SettlementState) -> void:
	settlement = next_settlement


func category_era(category: String) -> SettlementState.Era:
	match category:
		"earth": return SettlementState.Era.EARTH
		"clay": return SettlementState.Era.CLAY
		"wood": return SettlementState.Era.WOOD
		"stone": return SettlementState.Era.STONE
		"brick": return SettlementState.Era.BRICK
		_: return SettlementState.Era.TENT


func is_category_available(category: String) -> bool:
	return settlement != null and category_era(category) <= settlement.era


func menu_state(building_type: String) -> Dictionary:
	return menu_state_with_inventory(building_type, {})


func menu_state_with_inventory(building_type: String, extra_inventory: Dictionary) -> Dictionary:
	var visible_state := _visibility_state(building_type)
	var affordable := false
	var disabled_reason: StringName = visible_state.reason
	if bool(visible_state.visible):
		affordable = _can_afford_with_inventory(building_type, extra_inventory)
		disabled_reason = REASON_OK
	return {
		"visible": bool(visible_state.visible),
		"enabled": bool(visible_state.visible),
		"affordable": affordable,
		"reason": disabled_reason,
		"cost_text": cost_text(building_type, extra_inventory),
	}


func placement_state(building_type: String) -> Dictionary:
	return placement_state_with_inventory(building_type, {})


func placement_state_with_inventory(building_type: String, extra_inventory: Dictionary) -> Dictionary:
	var visible_state := _visibility_state(building_type)
	var affordable := false
	if bool(visible_state.visible):
		affordable = _can_afford_with_inventory(building_type, extra_inventory)
	if not bool(visible_state.visible):
		return {
			"allowed": false,
			"affordable": false,
			"reason": visible_state.reason,
			"message": message_for_reason(visible_state.reason),
		}
	return {
		"allowed": true,
		"affordable": affordable,
		"reason": REASON_OK,
		"message": "",
	}


func _can_afford_with_inventory(building_type: String, extra_inventory: Dictionary) -> bool:
	if not settlement.is_building_unlocked(building_type):
		return false
	if BuildingCatalog.era_for(building_type) > settlement.era:
		return false
	for resource_type in BuildingCatalog.cost_resources(building_type):
		var available := settlement.available_amount(resource_type)
		if extra_inventory.has(resource_type):
			available += int(extra_inventory[resource_type])
		if available < BuildingCatalog.cost_for_resource(building_type, resource_type):
			return false
	return true


func cost_text(building_type: String, extra_inventory: Dictionary = {}) -> String:
	var parts: Array[String] = []
	for resource_type in BuildingCatalog.cost_resources(building_type):
		var required := BuildingCatalog.cost_for_resource(building_type, resource_type)
		var have := settlement.available_amount(resource_type)
		if extra_inventory.has(resource_type):
			have += int(extra_inventory[resource_type])
		parts.append("%d/%d %s" % [have, required, resource_type])
	return "  ".join(parts) if not parts.is_empty() else "free"


func message_for_reason(reason: StringName) -> String:
	match reason:
		REASON_NO_FLAG:
			return "Build a settlement flag first."
		REASON_NO_CAMPFIRE:
			return "Build a campfire first."
		REASON_LATER_ERA:
			return "This building belongs to a later era. Complete the current settlement requirements first."
		REASON_LOCKED:
			return "This building is not unlocked yet."
		REASON_UPGRADE_ONLY:
			return "This landmark level is upgraded from the campfire menu."
		REASON_NOT_ENOUGH_RESOURCES:
			return "Not enough resources for this building."
		_:
			return ""


func _visibility_state(building_type: String) -> Dictionary:
	if settlement == null or building_type.is_empty():
		return {"visible": false, "reason": REASON_EMPTY}
	if BuildingCatalog.is_upgrade_only(building_type):
		return {"visible": false, "reason": REASON_UPGRADE_ONLY}
	if BuildingCatalog.era_for(building_type) > settlement.era:
		return {"visible": false, "reason": REASON_LATER_ERA}
	if not settlement.is_building_unlocked(building_type):
		return {"visible": false, "reason": REASON_LOCKED}
	return {"visible": true, "reason": REASON_OK}
