class_name MapStartOption
extends RefCounted

## One named way into a map (design_docs/engine/map_start.md §3).
##
## A start option is not a coordinate. It is a spawn group, a camera, a set of
## parameter overrides, some initial scenario flags and the conditions under
## which a player may pick it. One pair of hero/companion anchors per map does
## not scale to a free game with several landing sites, to a scenario whose
## prologue depends on the entrance, or to a team's corner in multiplayer — and
## all three are the same shape, which is why they are one record.
##
## What is deliberately **not** here (§3.1): a loose list of items and a loose
## list of characters. The first is a loadout, the second a party definition;
## both are reusable pack content the option only references. Inlining them means
## two entrances to one map hold two copies of the same backpack, and the copies
## drift apart on the first edit.

var id: StringName = &""
var name: Dictionary = {}
var description: Dictionary = {}
## Preview image, as a path inside the `.gdmap` package.
var thumbnail := ""
## Whether the player may pick this entrance in the launch screen. A scenario-only
## entrance stays authored and unlisted.
var selectable := true
## Game definitions this entrance makes sense for; empty means all of them.
var enabled_for: Array[StringName] = []
var spawn_group: StringName = &""
## Anchor carrying `core:camera_start` — where the first frame looks from (§4.1).
var camera: StringName = &""
## Party definition; empty means the one the game definition names (phase 2).
var party: StringName = &""
## `module_id -> ModuleSettingsSection`, level 4 of §2.5.
var module_overrides: Dictionary = {}
## Initial values of declared scenario flags — one scenario, a different prologue
## per entrance.
var flags: Dictionary = {}
## Free labels: a filter in the UI, a condition in a rule, a hint to balance.
var tags: Array[StringName] = []


static func from_dict(source: Dictionary) -> MapStartOption:
	var option := MapStartOption.new()
	option.id = StringName(source.get("id", ""))
	option.name = _localized(source.get("name"))
	option.description = _localized(source.get("description"))
	option.thumbnail = String(source.get("thumbnail", ""))
	option.selectable = bool(source.get("selectable", true))
	for entry: Variant in source.get("enabled_for", []):
		option.enabled_for.append(StringName(entry))
	option.spawn_group = StringName(source.get("spawn_group", ""))
	option.camera = StringName(source.get("camera", ""))
	option.party = StringName(source.get("party", ""))
	option.module_overrides = ModuleSettingsSection.map_from_dict(source.get("module_overrides", {}))
	if source.get("flags") is Dictionary:
		option.flags = (source["flags"] as Dictionary).duplicate(true)
	for tag: Variant in source.get("tags", []):
		option.tags.append(StringName(tag))
	return option


func to_dict() -> Dictionary:
	var result: Dictionary = {"id": String(id), "selectable": selectable}
	if not name.is_empty():
		result["name"] = name.duplicate()
	if not description.is_empty():
		result["description"] = description.duplicate()
	if not thumbnail.is_empty():
		result["thumbnail"] = thumbnail
	if not enabled_for.is_empty():
		result["enabled_for"] = enabled_for.map(func(value: StringName) -> String: return String(value))
	if spawn_group != &"":
		result["spawn_group"] = String(spawn_group)
	if camera != &"":
		result["camera"] = String(camera)
	if party != &"":
		result["party"] = String(party)
	var overrides := ModuleSettingsSection.map_to_dict(module_overrides)
	if not overrides.is_empty():
		result["module_overrides"] = overrides
	if not flags.is_empty():
		result["flags"] = flags.duplicate(true)
	if not tags.is_empty():
		result["tags"] = tags.map(func(tag: StringName) -> String: return String(tag))
	return result


func display_name() -> String:
	return MapLocalizedText.read(name, String(id))


func display_description() -> String:
	return MapLocalizedText.read(description)


## Whether this entrance means anything for the game about to be launched (§3.4).
func suits_definition(definition: StringName) -> bool:
	return enabled_for.is_empty() or definition in enabled_for


static func _localized(source: Variant) -> Dictionary:
	if source is Dictionary:
		return (source as Dictionary).duplicate()
	if source is String and not (source as String).is_empty():
		return {"ru": String(source)}
	return {}
