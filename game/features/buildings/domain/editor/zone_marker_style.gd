class_name ZoneMarkerStyle
extends RefCounted

## How a zone reads in the 3D view of either editor
## (design_docs/engine/active_zones.md §11, §11.2).
##
## "Отличий в модели нет — те же инструменты и тот же инспектор" is a promise
## about the eye as much as about the data: a waypoint that is grey in a building
## and lilac on a map costs the author the one thing this shared model was for.
## Both zones modes read their colours and sizes here.
##
## Colours are the only presentation detail in `domain/`, and deliberately so:
## they are a property of the shared authoring vocabulary, not of one editor's
## panel. Nothing here touches a node.

const AREA_COLORS: Array[Color] = [
	Color(0.35, 0.65, 1.0), Color(0.45, 0.85, 0.55), Color(0.95, 0.75, 0.35),
	Color(0.8, 0.55, 0.95), Color(0.95, 0.55, 0.55), Color(0.5, 0.85, 0.85),
]
const OVERLAY_COLOR := Color(1.0, 0.35, 0.35)
const SELECTION_COLOR := Color(1.0, 1.0, 1.0)

## Per anchor role, so a glance tells the author what is where without selecting.
const ANCHOR_STYLE: Dictionary = {
	ZoneAnchorRecord.ROLE_DOOR: {"color": Color(1.0, 0.55, 0.2), "size": Vector3(0.5, 1.8, 0.5)},
	ZoneAnchorRecord.ROLE_SLOT: {"color": Color(0.4, 1.0, 0.4), "size": Vector3(0.45, 1.2, 0.45)},
	ZoneAnchorRecord.ROLE_QUEUE: {"color": Color(0.9, 0.9, 0.4), "size": Vector3(0.35, 0.6, 0.35)},
	ZoneAnchorRecord.ROLE_STORAGE: {"color": Color(0.4, 0.8, 1.0), "size": Vector3(0.7, 0.3, 0.7)},
	ZoneAnchorRecord.ROLE_SPAWN: {"color": Color(0.8, 0.5, 1.0), "size": Vector3(0.5, 0.9, 0.5)},
	ZoneAnchorRecord.ROLE_WAYPOINT: {"color": Color(0.7, 0.7, 0.7), "size": Vector3(0.3, 0.5, 0.3)},
	ZoneAnchorRecord.ROLE_POI: {"color": Color(1.0, 0.8, 0.6), "size": Vector3(0.4, 0.9, 0.4)},
}

## Spawn functions the engine's own launch path distinguishes (`MapSpawnService`).
## A function this build does not interpret still draws as a spawn — the point of
## the fallback is that an unknown pack function is normal, not an error.
const SPAWN_FUNCTION_STYLE: Dictionary = {
	&"core:hero_start": {"color": Color(1.0, 0.82, 0.25), "size": Vector3(0.5, 1.1, 0.5), "label": "Герой"},
	&"core:companion_start": {"color": Color(0.45, 0.7, 1.0), "size": Vector3(0.45, 0.9, 0.45), "label": "Житель"},
}


static func of_anchor(anchor: ZoneAnchorRecord) -> Dictionary:
	if anchor.is_spawn() and SPAWN_FUNCTION_STYLE.has(anchor.function):
		return SPAWN_FUNCTION_STYLE[anchor.function]
	return ANCHOR_STYLE.get(anchor.role, {"color": Color(0.6, 0.6, 0.65), "size": Vector3(0.4, 0.8, 0.4)})


static func color_of_anchor(anchor: ZoneAnchorRecord) -> Color:
	return of_anchor(anchor)["color"]


static func size_of_anchor(anchor: ZoneAnchorRecord) -> Vector3:
	return of_anchor(anchor)["size"]


## Colour of an area: overlays are always the one warning colour (they are the
## exception, and there are few of them), everything else cycles the palette by
## authoring index so two neighbouring rooms never come out the same.
static func color_of_area(area: ZoneAreaRecord, index: int) -> Color:
	if area.is_overlay():
		return OVERLAY_COLOR
	return AREA_COLORS[index % AREA_COLORS.size()]


## Short glyph used in every list and tree of both editors.
static func glyph_of_role(role: StringName) -> String:
	match role:
		ZoneAnchorRecord.ROLE_DOOR: return "▽"
		ZoneAnchorRecord.ROLE_SLOT: return "◆"
		ZoneAnchorRecord.ROLE_QUEUE: return "◇"
		ZoneAnchorRecord.ROLE_STORAGE: return "▤"
		ZoneAnchorRecord.ROLE_SPAWN: return "✦"
		ZoneAnchorRecord.ROLE_WAYPOINT: return "·"
		ZoneAnchorRecord.ROLE_POI: return "◎"
		ZoneAreaRecord.ROLE_ROOM: return "▣"
		ZoneAreaRecord.ROLE_REGION: return "▣"
		ZoneAreaRecord.ROLE_OVERLAY: return "▨"
	return "•"
