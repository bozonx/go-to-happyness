class_name EditorTestPointMarkers
extends RefCounted

## Draws the cones an author aims a test run at (`EditorTestPoints`).
##
## Shared by both editors for the same reason the record is: the marker *is* the
## gesture's feedback, and the two editors had a line-for-line copy each. They
## drifted the moment one of them changed colour, and a marker that looks
## different in the building editor reads as a different kind of thing.
##
## The caller supplies where a point stands, because that is the one part the two
## do not share: a map point sits on the live terrain of a board cell, a building
## point on a floor of the frame.

## Colour of the point `F5` will use, and of the rest.
const AIMED_COLOR := Color(1.0, 0.55, 0.15, 0.85)
const IDLE_COLOR := Color(0.35, 0.75, 1.0, 0.7)
## Half the cone's length: the mesh is centred, so this is what lifts its tip onto
## the ground the caller named.
const CONE_LIFT := 0.6


## Rebuilds every marker under `root`. `ground_of` takes an `EditorTestPoints.Point`
## and answers where it stands, in `root`'s space.
static func rebuild(root: Node3D, points: EditorTestPoints, ground_of: Callable) -> void:
	# `free` and not `queue_free`: a rename rebuilds immediately after, and a
	# deferred free would leave the old markers readable for a frame, so the label
	# read right after a rename would still show the old name.
	for child in root.get_children():
		child.free()
	for index in points.points.size():
		var point: EditorTestPoints.Point = points.points[index]
		root.add_child(_marker(point, index, index == points.selected, ground_of.call(point)))


static func _marker(
	point: EditorTestPoints.Point, index: int, aimed: bool, ground: Vector3,
) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.45
	mesh.height = CONE_LIFT * 2.0
	marker.mesh = mesh
	# A cone standing on its point, so it reads as "here" rather than as one more
	# box among the zone markers.
	marker.rotation.x = PI
	var material := StandardMaterial3D.new()
	material.albedo_color = AIMED_COLOR if aimed else IDLE_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Visible through the geometry: the point of a marker you keep coming back to
	# is being findable from any camera angle, including from behind a hill or a
	# wall the author has just built.
	material.no_depth_test = true
	marker.material_override = material
	marker.position = ground + Vector3(0.0, CONE_LIFT, 0.0)
	var label := Label3D.new()
	label.text = "%d. %s" % [index + 1, point.display_name(index)]
	label.font_size = 44
	label.outline_size = 16
	label.outline_modulate = Color.BLACK
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	# The cone is upside down, so its local −Y is above the tip.
	label.position = Vector3(0.0, -(CONE_LIFT + 0.5), 0.0)
	marker.add_child(label)
	return marker
