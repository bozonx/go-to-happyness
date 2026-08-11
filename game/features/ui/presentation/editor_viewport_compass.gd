class_name EditorViewportCompass
extends Label

## Shared north indicator for freely orbiting authored-content viewports.
## North is the engine's -Z direction; callers only provide their active camera.

const ARROWS: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]


func update_from_camera(camera: Camera3D) -> void:
	if camera == null:
		return
	var north := Vector3(0.0, 0.0, -1.0)
	var basis := camera.global_transform.basis
	var screen := Vector2(basis.x.dot(north), basis.y.dot(north))
	if screen.length_squared() < 0.0001:
		return
	var clockwise_from_up := fposmod(rad_to_deg(atan2(screen.x, screen.y)), 360.0)
	text = "N %s" % ARROWS[int(round(clockwise_from_up / 45.0)) % ARROWS.size()]
