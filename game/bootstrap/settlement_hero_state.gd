class_name SettlementHeroState
extends RefCounted

## Hero citizen and pocket-menu state.
## Extracted from SettlementGame to reduce its field count.

var hero_citizen: Citizen
var pocket_menu_open := false
var pocket_take_warehouse_index: int = -1
