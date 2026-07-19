class_name CampfireOrdersMenu
extends Panel

var road_walking_toggle: CheckButton
var balanced_warehouse_toggle: CheckButton
var night_work_button: CheckButton
var double_time_button: CheckButton
var cheer_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -210.0
	offset_top = -190.0
	offset_right = 210.0
	offset_bottom = 190.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.18, 0.75)
	style.border_color = Color(0.25, 0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false

	var title := Label.new()
	title.text = "Campfire Orders"
	title.position = Vector2(18, 16)
	title.size = Vector2(384, 28)
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	road_walking_toggle = CheckButton.new()
	road_walking_toggle.text = "Walk as if on roads"
	road_walking_toggle.position = Vector2(18, 58)
	road_walking_toggle.size = Vector2(384, 32)
	road_walking_toggle.tooltip_text = "Residents trample trails faster. Route selection is unchanged."
	add_child(road_walking_toggle)

	balanced_warehouse_toggle = CheckButton.new()
	balanced_warehouse_toggle.text = "Balanced warehouse storage"
	balanced_warehouse_toggle.position = Vector2(18, 96)
	balanced_warehouse_toggle.size = Vector2(384, 32)
	balanced_warehouse_toggle.tooltip_text = "Spread each good evenly between warehouses instead of filling the nearest one."
	add_child(balanced_warehouse_toggle)

	night_work_button = CheckButton.new()
	night_work_button.text = "Work through the night"
	night_work_button.position = Vector2(18, 134)
	night_work_button.size = Vector2(384, 32)
	night_work_button.tooltip_text = "Affected workers continue through the night and next workday."
	add_child(night_work_button)

	double_time_button = CheckButton.new()
	double_time_button.text = "Double time"
	double_time_button.position = Vector2(18, 172)
	double_time_button.size = Vector2(384, 32)
	double_time_button.tooltip_text = "All residents walk twice as fast today. Fatigue accumulates 50%% faster and satisfaction drops."
	add_child(double_time_button)

	var description := Label.new()
	description.text = "Night work raises fatigue and lowers satisfaction. Dangerously tired residents may collapse while returning home.\nDouble time doubles walk speed but accelerates fatigue by 50%% and lowers satisfaction."
	description.position = Vector2(18, 212)
	description.size = Vector2(384, 60)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	add_child(description)

	cheer_button = Button.new()
	cheer_button.text = "Cheer up"
	cheer_button.position = Vector2(18, 280)
	cheer_button.size = Vector2(384, 32)
	cheer_button.tooltip_text = "Once per day. Raises wellbeing by 5%%."
	add_child(cheer_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(286, 288)
	close_button.size = Vector2(116, 32)
	close_button.pressed.connect(func(): close_requested.emit())
	add_child(close_button)


signal close_requested
