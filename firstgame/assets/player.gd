extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -250.0

var running = false
var jumping = false 
var attacking = false


@onready var sprite = $Animace

func _ready():
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumping = true
	
	if is_on_floor():
		jumping = false

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("move_left", "move_right")


	#animace pro běh
	var running := direction != 0

	
	
	#otáčení sprite
	if direction == 1:
		sprite.flip_h = false
	elif direction == -1:
		sprite.flip_h = true
	
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	#animace
	if running and is_on_floor() and !jumping:
		sprite.play("run")
	elif !running and is_on_floor() and !jumping:
		sprite.play("idle")
	elif !is_on_floor():
		sprite.play("jump")
	
	print("skáče?: ", jumping)
	print("běží?: ", running)
	print("je na zemi?: ", is_on_floor())
	print("utoci?: ", attacking)
	
	move_and_slide()
