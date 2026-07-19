class_name ResearchMenu
extends Panel

signal close_requested
signal start_requested(tech_id: String)
signal cancel_requested

@onready var title_label: Label = $TitleLabel
@onready var research_list: VBoxContainer = $ScrollContainer/ResearchList


func _ready() -> void:
	$CloseButton.pressed.connect(func(): close_requested.emit())


func update_state(state: Dictionary) -> void:
	title_label.text = state.title_text
	for child in research_list.get_children():
		child.queue_free()

	for item in state.tech_rows:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(604, 40)
		research_list.add_child(row)

		var details_vbox := VBoxContainer.new()
		details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details_vbox)

		var title_lbl := Label.new()
		title_lbl.text = item.title
		title_lbl.add_theme_font_size_override("font_size", 14)
		details_vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = item.description
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color("a5b5c5"))
		details_vbox.add_child(desc_lbl)

		if item.completed:
			var status_lbl := Label.new()
			status_lbl.text = "Researched"
			status_lbl.add_theme_color_override("font_color", Color("76c893"))
			row.add_child(status_lbl)
		elif item.active:
			var progress_vbox := VBoxContainer.new()
			progress_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(progress_vbox)

			var progress_lbl := Label.new()
			progress_lbl.text = "Researching: %d%%" % int(item.progress_pct)
			progress_lbl.add_theme_font_size_override("font_size", 11)
			progress_vbox.add_child(progress_lbl)

			var cancel_btn := Button.new()
			cancel_btn.text = "Cancel"
			cancel_btn.pressed.connect(cancel_requested.emit)
			row.add_child(cancel_btn)
		else:
			var start_btn := Button.new()
			start_btn.text = "Start"
			start_btn.disabled = not item.can_start
			start_btn.tooltip_text = item.tooltip
			start_btn.pressed.connect(start_requested.emit.bind(item.tech_id))
			row.add_child(start_btn)
