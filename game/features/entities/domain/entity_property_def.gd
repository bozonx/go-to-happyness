class_name EntityPropertyDef
extends RefCounted

## One authored property of an archetype, and everything the inspector needs to
## draw a control for it (design_docs/engine/map_fill_mode.md §7).
##
## The inspector is **generated from these, never written per type** (§7.1). That
## is the whole reason this class exists: the moment a control appears in code
## under `if archetype.id == "tree"`, a new genre module stops getting an editor
## for free, and the engine is back to being "a settlement with flags".
##
## The list of control types is therefore closed (§7.2) — each one is a widget
## somebody has to write — while the *properties* using them are open data.

const TYPE_BOOL := &"bool"
const TYPE_INT := &"int"
const TYPE_FLOAT := &"float"
const TYPE_STRING := &"string"
const TYPE_TEXT := &"text"
const TYPE_COLOR := &"color"
const TYPE_ENUM := &"enum"
const TYPE_FLAGS := &"flags"
const TYPE_VECTOR2 := &"vector2"
const TYPE_VECTOR3 := &"vector3"
## A value that varies over the time of day or the season, not a single number.
const TYPE_CURVE_TIME := &"curve_time"
## A repeating group — a schedule, a loot table — described by `entries`.
const TYPE_LIST := &"list"

## The reference family (§7.2). Half the value of the inspector is here: every one
## of these gets a "point at it on the map" button, and every one is stored as an
## identifier, which is what makes the validator able to catch a dangling link.
const TYPE_ASSET_REF := &"asset_ref"
const TYPE_ARCHETYPE_REF := &"archetype_ref"
const TYPE_ENTITY_REF := &"entity_ref"
const TYPE_ZONE_REF := &"zone_ref"
const TYPE_POINT_REF := &"point_ref"
const TYPE_ROUTE_REF := &"route_ref"
const TYPE_ITEM_REF := &"item_ref"
const TYPE_DIALOG_REF := &"dialog_ref"
const TYPE_QUEST_REF := &"quest_ref"
const TYPE_FLAG_REF := &"flag_ref"

const REFERENCE_TYPES: Array[StringName] = [
	TYPE_ASSET_REF, TYPE_ARCHETYPE_REF, TYPE_ENTITY_REF, TYPE_ZONE_REF,
	TYPE_POINT_REF, TYPE_ROUTE_REF, TYPE_ITEM_REF, TYPE_DIALOG_REF,
	TYPE_QUEST_REF, TYPE_FLAG_REF,
]

const VALUE_TYPES: Array[StringName] = [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_TEXT, TYPE_COLOR,
	TYPE_ENUM, TYPE_FLAGS, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_CURVE_TIME, TYPE_LIST,
]

## Fixed sections, so the inspector of a tree and of a merchant read the same way
## (§7.3). Empty sections are hidden; unavailable fields are shown disabled with
## an explanation rather than removed.
const SECTION_MAIN := &"main"
const SECTION_TRANSFORM := &"transform"
const SECTION_APPEARANCE := &"appearance"
const SECTION_STATE := &"state"
const SECTION_GAMEPLAY := &"gameplay"
const SECTION_BEHAVIOR := &"behavior"
const SECTION_LINKS := &"links"

## Display order of the sections. The inspector walks this array, so a property
## declaring an unknown section would silently vanish — `is_valid` refuses it.
const SECTIONS: Array[StringName] = [
	SECTION_MAIN, SECTION_TRANSFORM, SECTION_APPEARANCE, SECTION_STATE,
	SECTION_GAMEPLAY, SECTION_BEHAVIOR, SECTION_LINKS,
]

var name: StringName = &""
var label: String = ""
var type: StringName = TYPE_STRING
var default: Variant = null
var section: StringName = SECTION_GAMEPLAY
var unit: String = ""
var minimum: Variant = null
var maximum: Variant = null
var step: Variant = null
## `enum` and `flags` take their options from a pack dictionary, never from an
## enum in code: the list of factions is game data (§7.2).
var options_dictionary: StringName = &""
var options: Array = []
## `{"prop": "renewable", "eq": true}` — the field is drawn only when it holds.
var visible_if: Dictionary = {}
## Reference controls offer picking the target in the viewport.
var pick_on_map: bool = false
## Nested schema of a `list` property's repeating group.
var entries: Array[EntityPropertyDef] = []


static func is_reference_type(property_type: StringName) -> bool:
	return property_type in REFERENCE_TYPES


static func is_known_type(property_type: StringName) -> bool:
	return property_type in VALUE_TYPES or is_reference_type(property_type)


func is_reference() -> bool:
	return is_reference_type(type)


## A schema entry the inspector can actually draw. An unnamed property, an unknown
## control type or an unknown section would each produce a field the author never
## sees, so they are rejected at load rather than half-rendered.
func is_valid() -> bool:
	return name != &"" and is_known_type(type) and section in SECTIONS


## Whether this field is shown, given the current values of the record's own
## properties. A missing controlling property counts as not matching: the field
## stays hidden until the author sets the thing it depends on.
func is_visible_for(values: Dictionary) -> bool:
	if visible_if.is_empty():
		return true
	var controlling := StringName(visible_if.get("prop", ""))
	if controlling == &"":
		return true
	if not values.has(controlling):
		return false
	return values[controlling] == visible_if.get("eq", true)


## JSON has a single number type, so a pack declaring `"default": 8` hands us 8.0.
## A property declared `int` has to give the runtime an int all the same, or every
## consumer would carry its own `int()` and the first one to forget it would ship
## a float into a stack count. Coercion belongs here, once.
func coerce_value(value: Variant) -> Variant:
	if value == null:
		return null
	match type:
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_STRING, TYPE_TEXT:
			return String(value)
		TYPE_COLOR:
			if value is Color:
				return value
			return Color.html(String(value))
		TYPE_VECTOR2:
			return _as_vector(value, 2)
		TYPE_VECTOR3:
			return _as_vector(value, 3)
		_:
			return value


## Coerces, then clamps into the declared range. Only numbers have one; everything
## else passes through, because a range on a colour or a reference means nothing.
func clamp_value(value: Variant) -> Variant:
	var coerced: Variant = coerce_value(value)
	if type == TYPE_INT:
		var as_int := int(coerced)
		if minimum != null:
			as_int = maxi(as_int, int(minimum))
		if maximum != null:
			as_int = mini(as_int, int(maximum))
		return as_int
	if type == TYPE_FLOAT:
		var as_float := float(coerced)
		if minimum != null:
			as_float = maxf(as_float, float(minimum))
		if maximum != null:
			as_float = minf(as_float, float(maximum))
		return as_float
	return coerced


static func _as_vector(value: Variant, dimensions: int) -> Variant:
	if value is Vector2 or value is Vector3:
		return value
	if not (value is Array) or (value as Array).size() < dimensions:
		return Vector2.ZERO if dimensions == 2 else Vector3.ZERO
	var numbers := value as Array
	if dimensions == 2:
		return Vector2(float(numbers[0]), float(numbers[1]))
	return Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2]))


func to_dict() -> Dictionary:
	var result: Dictionary = {
		"name": String(name),
		"label": label,
		"type": String(type),
		"section": String(section),
	}
	if default != null:
		result["default"] = default
	if not unit.is_empty():
		result["unit"] = unit
	if minimum != null:
		result["min"] = minimum
	if maximum != null:
		result["max"] = maximum
	if step != null:
		result["step"] = step
	if options_dictionary != &"":
		result["options_dictionary"] = String(options_dictionary)
	if not options.is_empty():
		result["options"] = options.duplicate()
	if not visible_if.is_empty():
		result["visible_if"] = visible_if.duplicate()
	if pick_on_map:
		result["pick_on_map"] = true
	if not entries.is_empty():
		var nested: Array = []
		for entry: EntityPropertyDef in entries:
			nested.append(entry.to_dict())
		result["entries"] = nested
	return result


static func from_dict(source: Dictionary) -> EntityPropertyDef:
	var property := EntityPropertyDef.new()
	property.name = StringName(source.get("name", ""))
	property.label = String(source.get("label", String(property.name)))
	property.type = StringName(source.get("type", TYPE_STRING))
	property.section = StringName(source.get("section", SECTION_GAMEPLAY))
	property.unit = String(source.get("unit", ""))
	property.default = property.coerce_value(source.get("default", null))
	property.minimum = property.coerce_value(source.get("min", null))
	property.maximum = property.coerce_value(source.get("max", null))
	property.step = property.coerce_value(source.get("step", null))
	property.options_dictionary = StringName(source.get("options_dictionary", ""))
	var raw_options: Variant = source.get("options", null)
	if raw_options is Array:
		property.options = (raw_options as Array).duplicate()
	var raw_visible: Variant = source.get("visible_if", null)
	if raw_visible is Dictionary:
		property.visible_if = (raw_visible as Dictionary).duplicate()
	property.pick_on_map = bool(source.get("pick_on_map", false))
	var raw_entries: Variant = source.get("entries", null)
	if raw_entries is Array:
		for raw_entry: Variant in raw_entries as Array:
			if raw_entry is Dictionary:
				var entry := from_dict(raw_entry as Dictionary)
				if entry.is_valid():
					property.entries.append(entry)
	return property
