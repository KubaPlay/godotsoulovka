extends Node2D

func _ready() -> void:
	print("Scéna je připravena. Čekám na stisk Esc pro návrat do menu.")


func _process(_delta: float) -> void:

	if Input.is_action_just_pressed("ui_cancel"):
		print("Akce 'ui_cancel' (Esc) byla stisknuta. Měním scénu na menu...")
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
