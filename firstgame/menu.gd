extends Button # Důležité! Skript musí dědit z Button

# Není potřeba @export pro scénu, pokud ji měníte z tohoto tlačítka
# Pokud ale chcete scénu měnit na jinou, než je pevně daná, @export je stále užitečný
@export var scene_tutorial: PackedScene

func _ready():
	# 'self' zde odkazuje na tento uzel Button
	# Signál 'pressed' je vysílán tímto uzlem (self)
	# Připojíme ho k metodě '_on_this_button_pressed' definované v tomto skriptu
	self.pressed.connect(_on_this_button_pressed)
	# Můžete také napsat jen:
	# pressed.connect(_on_this_button_pressed)

func _on_this_button_pressed(): # Doporučuje se konvence "_on_NodeName_signal_name"
	print("Existující tlačítko bylo stisknuto!")
	if !scene_tutorial:
		get_tree().change_scene_to_file("res://scenes/scene_tutorial.tscn")
	else:
		print("CHYBA: Proměnná 'scene_to_load' není nastavena v inspektoru!")
