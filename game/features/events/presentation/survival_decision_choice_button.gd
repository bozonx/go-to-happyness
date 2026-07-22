class_name SurvivalDecisionChoiceButton
extends Button

var _choice_text: String = ""


func setup(choice_text: String) -> void:
	_choice_text = choice_text
	if is_node_ready():
		text = _choice_text


func _ready() -> void:
	if _choice_text != "":
		text = _choice_text
