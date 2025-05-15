extends CharacterBody2D

var speed: float = 100.0
var patrol_range: float = 150.0


var direction: int = 1
var start_x_position: float


var sprite_node: Sprite2D


func _ready():
	start_x_position = global_position.x


func _physics_process(_delta: float):
	velocity.x = direction * speed
	move_and_slide()

	if direction == 1 and global_position.x >= start_x_position + patrol_range:
		direction = -1
		global_position.x = start_x_position + patrol_range
		if sprite_node:
			sprite_node.flip_h = true
	elif direction == -1 and global_position.x <= start_x_position - patrol_range:
		direction = 1
		global_position.x = start_x_position - patrol_range
		if sprite_node:
			sprite_node.flip_h = false
