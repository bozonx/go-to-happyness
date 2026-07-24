class_name SettlementCameraState
extends RefCounted

## Camera drag/pan/rotate input flags.
## Extracted from SettlementGame to reduce its field count.
## Camera position values (distance, yaw, pitch, target) are already
## delegated to CameraController and are not duplicated here.

var is_panning_camera := false
var is_rotating_camera := false
var right_mouse_dragged := false
