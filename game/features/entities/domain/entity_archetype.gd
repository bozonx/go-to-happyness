class_name EntityArchetype
extends RefCounted

## What a thing *is* in the game, as pack data
## (design_docs/engine/map_fill_mode.md §4).
##
##   WorldAsset      — how it looks and where it may stand
##    └── EntityArchetype — what it is: components, states, authored properties
##         └── PlacedEntity   — where it stands and how it differs from this
##              └── EntityInstance — what became of it in a session
##
## Three models of a spruce are three assets; the archetype "spruce" is one. The
## archetype is what makes a tree fellable, and it is **data**: adding iron ore
## must not be a commit in GDScript.
##
## Components are listed, never enumerated in code (§4.1). The rule is: *the module
## that executes a component introduces it and validates its data.* This class
## therefore carries `components` as an opaque dictionary — the fill mode knows the
## name of exactly zero of them, which is the test that the engine is general
## rather than a settlement with flags.

## Three classes of content, split because their identity differs, not to optimise
## (§4.2). A pebble is anonymous and interchangeable; a tree must be able to
## *become* named the moment it is felled; a merchant is named always, because a
## quest, a rule and a save all point at him.
const CLASS_FILL := &"fill"
const CLASS_OBJECT := &"object"
const CLASS_ACTOR := &"actor"

const CONTENT_CLASSES: Array[StringName] = [CLASS_FILL, CLASS_OBJECT, CLASS_ACTOR]

## Activity policy (§5.3). Declared from the start even though the runtime that
## honours it does not exist yet: adding it later would mean rewriting every map
## already authored.
const ACTIVITY_ALWAYS := &"always"
const ACTIVITY_DISTANCE := &"distance"
const ACTIVITY_ON_TRIGGER := &"on_trigger"

const ACTIVITY_POLICIES: Array[StringName] = [
	ACTIVITY_ALWAYS, ACTIVITY_DISTANCE, ACTIVITY_ON_TRIGGER,
]

const FILE_SUFFIX := ".gdarchetype.json"
const FORMAT_VERSION := 1

var id: StringName = &""
var name: String = ""
## Default asset this archetype is drawn with. A record may override it — three
## spruce models, one archetype — but "the same spruce as indestructible fill" is
## a different archetype, not a flag (§4).
var asset_id: StringName = &""
var content_class: StringName = CLASS_OBJECT
var category: StringName = &"world_props"
var tags: Array[StringName] = []
var activity: StringName = ACTIVITY_DISTANCE
## An archetype that cannot live as a record and a `MultiMesh` instance has to say
## so, because chunked instancing is the only way to hold tens of thousands of
## objects (§9.4). Saying it here is what lets the palette show the author the
## cost.
var requires_persistent_node: bool = false
## Component name → its data. Validated by the module that executes it, never here.
var components: Dictionary = {}
var property_schema: Array[EntityPropertyDef] = []
var states := EntityStateSet.new()


static func create(
	p_id: StringName,
	p_name: String,
	p_asset_id: StringName,
	p_content_class: StringName = CLASS_OBJECT
) -> EntityArchetype:
	var archetype := EntityArchetype.new()
	archetype.id = p_id
	archetype.name = p_name
	archetype.asset_id = p_asset_id
	archetype.content_class = p_content_class
	return archetype


func has_component(component: StringName) -> bool:
	return components.has(String(component))


func component_data(component: StringName) -> Dictionary:
	var raw: Variant = components.get(String(component), null)
	return (raw as Dictionary) if raw is Dictionary else {}


func component_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: Variant in components.keys():
		names.append(StringName(key))
	names.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return names


func get_property(property_name: StringName) -> EntityPropertyDef:
	for property: EntityPropertyDef in property_schema:
		if property.name == property_name:
			return property
	return null


## Defaults for every declared property. A placed record stores **only the
## author's differences** from this (§4), so that editing a default here reaches
## every object already on every map.
func default_properties() -> Dictionary:
	var values: Dictionary = {}
	for property: EntityPropertyDef in property_schema:
		if property.default != null:
			values[property.name] = property.default
	return values


func default_values() -> Dictionary:
	return default_properties()


## Strips values equal to the archetype default, and anything the schema does not
## declare. This is the function that keeps a forest out of `map.json`: without it
## every tree would store a full snapshot of its properties.
func authored_differences(values: Dictionary) -> Dictionary:
	var differences: Dictionary = {}
	for key: Variant in values.keys():
		var property := get_property(StringName(key))
		if property == null:
			continue
		var value: Variant = property.clamp_value(values[key])
		if property.default != null and value == property.default:
			continue
		differences[property.name] = value
	return differences


## The archetype's defaults with the author's differences laid over them — what the
## inspector shows and what the runtime starts from.
func resolved_properties(differences: Dictionary) -> Dictionary:
	var values := default_properties()
	for key: Variant in differences.keys():
		var property := get_property(StringName(key))
		if property != null:
			values[property.name] = property.clamp_value(differences[key])
	return values


func to_dict() -> Dictionary:
	var schema: Array = []
	for property: EntityPropertyDef in property_schema:
		schema.append(property.to_dict())
	var tag_ids: Array = []
	for tag: StringName in tags:
		tag_ids.append(String(tag))
	var result: Dictionary = {
		"version": FORMAT_VERSION,
		"id": String(id),
		"name": name,
		"asset": String(asset_id),
		"content_class": String(content_class),
		"category": String(category),
		"activity": String(activity),
	}
	if not tag_ids.is_empty():
		result["tags"] = tag_ids
	if requires_persistent_node:
		result["requires_persistent_node"] = true
	if not components.is_empty():
		result["components"] = components.duplicate(true)
	if not schema.is_empty():
		result["properties"] = schema
	if not states.is_empty():
		result["states"] = states.to_dict()
	return result


## Unknown enum values fall back to the default rather than failing the load: a
## map or pack authored by a later build must still open here (§11).
static func from_dict(source: Dictionary) -> EntityArchetype:
	var archetype := EntityArchetype.new()
	archetype.id = StringName(source.get("id", ""))
	archetype.name = String(source.get("name", String(archetype.id)))
	archetype.asset_id = StringName(source.get("asset", ""))
	var declared_class := StringName(source.get("content_class", CLASS_OBJECT))
	if declared_class in CONTENT_CLASSES:
		archetype.content_class = declared_class
	archetype.category = StringName(source.get("category", archetype.category))
	var declared_activity := StringName(source.get("activity", ACTIVITY_DISTANCE))
	if declared_activity in ACTIVITY_POLICIES:
		archetype.activity = declared_activity
	archetype.requires_persistent_node = bool(
		source.get("requires_persistent_node", false)
	)
	var raw_tags: Variant = source.get("tags", null)
	if raw_tags is Array:
		for tag: Variant in raw_tags as Array:
			archetype.tags.append(StringName(tag))
	var raw_components: Variant = source.get("components", null)
	if raw_components is Dictionary:
		archetype.components = (raw_components as Dictionary).duplicate(true)
	var raw_properties: Variant = source.get("properties", null)
	if raw_properties is Array:
		for raw_property: Variant in raw_properties as Array:
			if not (raw_property is Dictionary):
				continue
			var property := EntityPropertyDef.from_dict(raw_property as Dictionary)
			# A property the inspector cannot draw is dropped rather than
			# half-rendered: an invisible field the author cannot set is worse
			# than one that is honestly absent.
			if property.is_valid() and archetype.get_property(property.name) == null:
				archetype.property_schema.append(property)
	var raw_states: Variant = source.get("states", null)
	if raw_states is Dictionary:
		archetype.states = EntityStateSet.from_dict(raw_states as Dictionary)
	return archetype


static func from_json(text: String) -> EntityArchetype:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	var parsed: Dictionary = json.data
	var archetype := from_dict(parsed as Dictionary)
	return archetype if archetype.id != &"" else null


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")
