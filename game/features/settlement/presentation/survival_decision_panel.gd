class_name SurvivalDecisionPanel
extends Panel

signal choice_selected(index: int)

@onready var title_label: Label = $TitleLabel
@onready var description_label: Label = $DescriptionLabel

var _choice_buttons: Array[Button] = []


func show_event(title: String, description: String, choice_labels: Array[String]) -> void:
	title_label.text = title
	description_label.text = description
	for btn in _choice_buttons:
		btn.queue_free()
	_choice_buttons.clear()
	var y_offset := 194
	for i in range(choice_labels.size()):
		var btn := Button.new()
		btn.position = Vector2(20, y_offset)
		btn.size = Vector2(440, 32)
		btn.text = choice_labels[i]
		btn.pressed.connect(choice_selected.emit.bind(i))
		add_child(btn)
		_choice_buttons.append(btn)
		y_offset += 42
	visible = true


func hide_panel() -> void:
	visible = false
