class_name SchoolMenu
extends Panel

signal train_requested(role: String)
signal dev_toggled(role: String, pressed: bool)
signal demolish_requested

@onready var title_label: Label = $TitleLabel
@onready var demolish_btn: Button = $DemolishButton
@onready var close_btn: Button = $CloseButton

var train_buttons: Array[Button] = []
var dev_checkboxes: Dictionary = {}


func _ready() -> void:
	$TrainList/TrainConstruction.pressed.connect(func(): train_requested.emit("construction"))
	$TrainList/TrainForestry.pressed.connect(func(): train_requested.emit("forestry"))
	$TrainList/TrainFarming.pressed.connect(func(): train_requested.emit("farming"))
	$TrainList/TrainExcavation.pressed.connect(func(): train_requested.emit("excavation"))
	$TrainList/TrainFactoryWorker.pressed.connect(func(): train_requested.emit("factory_worker"))
	$TrainList/TrainEngineer.pressed.connect(func(): train_requested.emit("engineer"))
	$TrainList/TrainCook.pressed.connect(func(): train_requested.emit("cook"))
	$TrainList/TrainTeacher.pressed.connect(func(): train_requested.emit("teacher"))
	$TrainList/TrainSeller.pressed.connect(func(): train_requested.emit("seller"))
	
	$DevList/DevelopConstruction.toggled.connect(func(pressed): dev_toggled.emit("construction", pressed))
	$DevList/DevelopForestry.toggled.connect(func(pressed): dev_toggled.emit("forestry", pressed))
	$DevList/DevelopFarming.toggled.connect(func(pressed): dev_toggled.emit("farming", pressed))
	$DevList/DevelopExcavation.toggled.connect(func(pressed): dev_toggled.emit("excavation", pressed))
	$DevList/DevelopFactoryWorker.toggled.connect(func(pressed): dev_toggled.emit("factory_worker", pressed))
	$DevList/DevelopEngineer.toggled.connect(func(pressed): dev_toggled.emit("engineer", pressed))
	$DevList/DevelopCook.toggled.connect(func(pressed): dev_toggled.emit("cook", pressed))
	$DevList/DevelopTeacher.toggled.connect(func(pressed): dev_toggled.emit("teacher", pressed))
	$DevList/DevelopSeller.toggled.connect(func(pressed): dev_toggled.emit("seller", pressed))
	
	demolish_btn.pressed.connect(func(): demolish_requested.emit())
	close_btn.pressed.connect(func(): visible = false)
	
	train_buttons = [
		$TrainList/TrainConstruction,
		$TrainList/TrainForestry,
		$TrainList/TrainFarming,
		$TrainList/TrainExcavation,
		$TrainList/TrainFactoryWorker,
		$TrainList/TrainEngineer,
		$TrainList/TrainCook,
		$TrainList/TrainTeacher,
		$TrainList/TrainSeller
	]
	
	dev_checkboxes = {
		"construction": $DevList/DevelopConstruction,
		"forestry": $DevList/DevelopForestry,
		"farming": $DevList/DevelopFarming,
		"excavation": $DevList/DevelopExcavation,
		"factory_worker": $DevList/DevelopFactoryWorker,
		"engineer": $DevList/DevelopEngineer,
		"cook": $DevList/DevelopCook,
		"teacher": $DevList/DevelopTeacher,
		"seller": $DevList/DevelopSeller
	}
