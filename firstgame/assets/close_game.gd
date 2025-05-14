extends Button

func _ready():
	self.pressed.connect(_on_this_button_pressed)


func _on_this_button_pressed(): # Doporučuje se konvence "_on_NodeName_signal_name"
	get_tree().quit()
