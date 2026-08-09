class_name EditorStatusBar
extends PanelContainer

## Shared presentation for authoring-tool context, messages and shortcut help.
## Editors provide plain text; this component owns status decoration and colour.

@onready var _context_label: Label = $Margin/Row/ContextLabel
@onready var _message_label: Label = $Margin/Row/MessageLabel
@onready var _shortcut_tooltip: EditorShortcutTooltip = $Margin/Row/ShortcutTooltip


func set_context(text: String) -> void:
	_context_label.text = text


func set_message(message: String, severity: int = EditorStatusMessage.Severity.INFO) -> void:
	_message_label.text = EditorStatusMessage.text(message, severity)
	_message_label.add_theme_color_override("font_color", EditorStatusMessage.color(severity))


func set_shortcuts(text: String) -> void:
	_shortcut_tooltip.shortcuts_text = text
	var label: Label = _shortcut_tooltip.get_node_or_null("Popup/Margin/Label")
	if label != null:
		label.text = text
