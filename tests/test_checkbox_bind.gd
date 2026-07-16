extends SceneTree

func _init() -> void:
    var root = self.root
    var checkboxes: Array[CheckBox] = []
    var toggled_states: Dictionary = {}
    
    var resources := ["branches", "grass", "water"]
    for resource_type in resources:
        var cb := CheckBox.new()
        checkboxes.append(cb)
        cb.toggled.connect(_on_toggled.bind(resource_type, toggled_states))
        root.add_child(cb)
    
    # Simulate user toggling the second checkbox off
    checkboxes[1].button_pressed = false
    checkboxes[1].toggled.emit(false)
    
    assert(toggled_states.has("grass"), "Expected grass toggle to be recorded")
    assert(toggled_states["grass"] == false, "Expected grass toggle state to be false")
    assert(not toggled_states.has("branches"), "Did not expect branches toggle")
    assert(not toggled_states.has("water"), "Did not expect water toggle")
    
    print("PASS")
    quit(0)

func _on_toggled(resource_type: String, state: bool, out: Dictionary) -> void:
    out[resource_type] = state
