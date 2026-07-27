class_name EditorShortcutTooltip
extends Control

## Shared shortcut affordance for editor status bars. Godot's built-in tooltip is
## not interactive, so it cannot support both hover reading and click toggling.

const CLICK_GUARD_MS := 450

@export_multiline var shortcuts_text := ""

@onready var _button: Button = $HelpButton
@onready var _popup: PanelContainer = $Popup
@onready var _label: Label = $Popup/Margin/Label

var _shown_at_ms := 0
var _suppressed_until_leave := false


func _ready() -> void:
	_label.text = shortcuts_text
	_button.mouse_entered.connect(_show_from_hover)
	_button.mouse_exited.connect(_schedule_hide_if_left)
	_popup.mouse_entered.connect(_show_from_hover)
	_popup.mouse_exited.connect(_schedule_hide_if_left)
	_button.pressed.connect(_toggle_from_click)
	_popup.hide()


func _show_from_hover() -> void:
	if _suppressed_until_leave:
		return
	if not _popup.visible:
		_popup.show()
		_shown_at_ms = Time.get_ticks_msec()


func _toggle_from_click() -> void:
	# Entering the button reveals the hint. Ignore the immediately following
	# click so a reader who did not expect that reveal does not close it by
	# accident.
	if _popup.visible and Time.get_ticks_msec() - _shown_at_ms < CLICK_GUARD_MS:
		return
	if _popup.visible:
		_popup.hide()
		_suppressed_until_leave = true
	else:
		_suppressed_until_leave = false
		_popup.show()
		_shown_at_ms = Time.get_ticks_msec()


func _schedule_hide_if_left() -> void:
	call_deferred("_hide_if_pointer_left")


func _hide_if_pointer_left() -> void:
	if _button.get_global_rect().has_point(get_global_mouse_position()):
		return
	if _popup.visible and _popup.get_global_rect().has_point(get_global_mouse_position()):
		return
	_popup.hide()
	_suppressed_until_leave = false
