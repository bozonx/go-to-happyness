class_name SurvivalDecisionPanel
extends Panel

signal choice_selected(index: int)

const SurvivalDecisionChoiceButtonScene = preload("res://game/features/settlement/presentation/survival_decision_choice_button.tscn")

@onready var title_label: Label = $TitleLabel
@onready var description_label: Label = $DescriptionLabel
@onready var choices_vbox: VBoxContainer = $ChoicesVBox


func show_event(title: String, description: String, choice_labels: Array[String]) -> void:
	title_label.text = title
	description_label.text = description

	for child in choices_vbox.get_children():
		child.queue_free()

	for i in range(choice_labels.size()):
		var btn: SurvivalDecisionChoiceButton = SurvivalDecisionChoiceButtonScene.instantiate()
		btn.setup(choice_labels[i])
		btn.pressed.connect(choice_selected.emit.bind(i))
		choices_vbox.add_child(btn)

	visible = true


func hide_panel() -> void:
	visible = false
