extends CharacterBody2D

# Player Movement Variables
const MOVE_SPEED: float = 150.0
const JUMP_VELOCITY: float = -300.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


#health variables
var max_health: int = 100
var current_health: int

signal health_updated(new_health, max_hp)
signal died

# Dodge Variables
const DODGE_SPEED: float = 350.0
const DODGE_DURATION: float = 0.3  # How long the dodge invulnerability and movement lasts
const DODGE_COOLDOWN: float = 0.8 # How long before the player can dodge again
var is_dodging: bool = false
var is_dashing: bool = false
var can_dodge: bool = true
var dodge_direction: Vector2 = Vector2.ZERO
# IMPORTANT: If "enemies" is Layer 2 in Project Settings, its index is 1.
const ENEMY_PHYSICS_LAYER_BIT_INDEX: int = 1
const ENEMY_PHYSICS_MASK_BIT_INDEX: int = 1
# Attack Variables
var is_attacking: bool = false       # True if any attack animation is active or in combo window
var can_attack_from_neutral: bool = true  # True if player can start a new attack sequence
var attack_combo_count: int = 0    # 0: none, 1: m1, 2: m2
const ATTACK_COOLDOWN_TIME: float = 0.5 # Cooldown after a full combo or single attack
const COMBO_WINDOW_TIME: float = 0.3  # Time after m1 finishes to input m2

# Animation Names (ADJUST THESE TO MATCH YOUR ANIMATIONS)
const ANIM_IDLE: StringName = "idle"
const ANIM_RUN: StringName = "run"
const ANIM_JUMP: StringName = "jump"
const ANIM_DODGE: StringName = "dodge"
const ANIM_DASH: StringName = "dash"
const ANIM_ATTACK_M1: StringName = "m1"
const ANIM_ATTACK_M2: StringName = "m2"
const ANIM_JUMP_ATTACK: StringName = "jumpAttack"

@onready var animated_sprite: AnimatedSprite2D = $Animace
@onready var dodge_duration_timer: Timer = $DodgeDurationTimer
@onready var dodge_cooldown_timer: Timer = $DodgeCooldownTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var combo_window_timer: Timer = $ComboWindowTimer

func _ready() -> void:
	#health
	current_health = max_health
	health_updated.emit(current_health, max_health)
	
	# Dodge Timers
	dodge_duration_timer.wait_time = DODGE_DURATION
	dodge_duration_timer.one_shot = true
	dodge_duration_timer.timeout.connect(_on_DodgeDurationTimer_timeout)

	dodge_cooldown_timer.wait_time = DODGE_COOLDOWN
	dodge_cooldown_timer.one_shot = true
	dodge_cooldown_timer.timeout.connect(_on_DodgeCooldownTimer_timeout)

	# Attack Timers
	attack_cooldown_timer.wait_time = ATTACK_COOLDOWN_TIME
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.timeout.connect(_on_AttackCooldownTimer_timeout)

	combo_window_timer.wait_time = COMBO_WINDOW_TIME
	combo_window_timer.one_shot = true
	combo_window_timer.timeout.connect(_on_ComboWindowTimer_timeout)

	animated_sprite.animation_finished.connect(_on_AnimatedSprite_animation_finished)

#health functions
func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func take_damage(damage_amount: int) -> void:
	if current_health <= 0: # Already dead, do nothing
		return

	current_health -= damage_amount
	current_health = clamp(current_health, 0, max_health) # Ensure health doesn't go below 0 or above max
	print("Player took ", damage_amount, " damage. Current health: ", current_health, "/", max_health)
	health_updated.emit(current_health, max_health)

	if current_health <= 0:
		_die()

func _die() -> void:
	print("Player has died!")
	died.emit()
	# Add death behavior here:
	# - Play death animation
	# - Disable player input
	# - Show game over screen
	# - For now, let's just make the player disappear (or disable collision)
	# is_attacking = false # Stop any current actions
	# is_dodging = false
	# set_physics_process(false) # Stop processing physics
	# visible = false
	# $CollisionShape2D.disabled = true # Assuming your collision shape is named CollisionShape2D
	queue_free() # Or handle respawn/game over logic

# Optional: A function to heal
func heal(heal_amount: int) -> void:
	if current_health <= 0: # Can't heal if dead
		return
	current_health += heal_amount
	current_health = clamp(current_health, 0, max_health)
	health_updated.emit(current_health, max_health)
	print("Player healed ", heal_amount, " health. Current health: ", current_health, "/", max_health)





func get_input_direction_x() -> float:
	return Input.get_axis("move_left", "move_right")

func _physics_process(delta: float) -> void:
	var input_dir_x: float = get_input_direction_x()

	# --- Handle Inputs ---
	if Input.is_action_just_pressed("dodge") and can_dodge and not is_dodging and not is_attacking:
		_start_dodge(input_dir_x)

	if Input.is_action_just_pressed("attack") and not is_dodging: # Can't attack while dodging
		_handle_attack_input(input_dir_x)

	# --- Apply Gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta

	# --- Movement Logic based on State ---
	if is_dodging or is_dashing:
		velocity = dodge_direction * DODGE_SPEED
	elif is_attacking:
		# Minimal movement during attacks, can be customized
		if is_on_floor(): # Ground attadcks might root or slow player
			velocity.x = move_toward(velocity.x, 0, MOVE_SPEED / 2) # Example: Slower strafe or stop
		else: # Jump attack allows air strafing
			velocity.x = input_dir_x * MOVE_SPEED
	else: # Normal Movement (not dodging, not attacking)
		velocity.x = input_dir_x * MOVE_SPEED
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			# Instantly play jump animation to feel responsive, _update_animation will confirm
			if animated_sprite.animation != ANIM_JUMP: animated_sprite.play(ANIM_JUMP)


	move_and_slide()
	_update_animation(input_dir_x) # Pass input_dir_x for facing decisions

func _handle_attack_input(current_input_dir_x: float) -> void:
	if is_attacking: # If an attack is already in progress (could be m1 animation or combo window)
		if attack_combo_count == 1 and not combo_window_timer.is_stopped(): # Check if in combo window after m1
			combo_window_timer.stop() # Consume the window
			attack_combo_count = 2    # Progress to m2
			# is_attacking remains true
			# can_attack_from_neutral remains false
			# Sprite will flip based on current_input_dir_x if needed, or keep m1 facing
			if current_input_dir_x != 0: animated_sprite.flip_h = current_input_dir_x < 0
			print("Player: Combo to M2")
			# _update_animation will play ANIM_ATTACK_M2
	elif can_attack_from_neutral: # Start a new attack sequencess
		is_attacking = true
		can_attack_from_neutral = false # Prevent new sequences until cooldown
		
		# Flip sprite based on input at the start of the attack
		if current_input_dir_x != 0:
			animated_sprite.flip_h = current_input_dir_x < 0
		# If no input, keeps current facing

		if not is_on_floor():
			attack_combo_count = 0 # Special value for jump attack, or use a specific ID
			print("Player: Jump Attack")
		else: # Ground attack
			attack_combo_count = 1 # Start with m1
			print("Player: M1 Attack")
		# _update_animation will play the correct starting attack animation

func _start_dodge(current_input_dir_x: float) -> void:
	if is_on_floor(): is_dodging = true
	elif !is_on_floor():
		is_dodging = false
		is_dashing = true
	can_dodge = false # Dodge on cooldown
	
	if current_input_dir_x != 0:
		dodge_direction = Vector2(current_input_dir_x, 0).normalized()
	elif animated_sprite.flip_h: # Dodge in current facing direction if no input
		dodge_direction = Vector2.LEFT
	else:
		dodge_direction = Vector2.RIGHT

	set_collision_mask_value(ENEMY_PHYSICS_MASK_BIT_INDEX, false) # Collide with enemies again
	set_collision_layer_value(ENEMY_PHYSICS_LAYER_BIT_INDEX, false) # Ignore enemies
	dodge_duration_timer.start()
	# _update_animation will play ANIM_DODGE

func _end_dodge() -> void:
	is_dodging = false
	is_dashing = false
	set_collision_mask_value(ENEMY_PHYSICS_MASK_BIT_INDEX, true) # Collide with enemies again
	set_collision_layer_value(ENEMY_PHYSICS_LAYER_BIT_INDEX, true)
	dodge_cooldown_timer.start()

func _reset_attack_state() -> void:
	is_attacking = false
	attack_combo_count = 0
	combo_window_timer.stop() # Ensure combo window is cleared
	attack_cooldown_timer.start() # Start cooldown for starting a new attack sequence

func _update_animation(current_input_dir_x: float) -> void:
	var new_anim: StringName = animated_sprite.animation # Default to current to avoid needless restarts

	if is_attacking:
		if not is_on_floor(): # Check this first for jump attack priority
			new_anim = ANIM_JUMP_ATTACK
		elif attack_combo_count == 1:
			new_anim = ANIM_ATTACK_M1
		elif attack_combo_count == 2:
			new_anim = ANIM_ATTACK_M2
		# If attack_combo_count is 0 but is_attacking is true and on_floor, it's an edge case,
		# perhaps reset or play idle. For now, assume jump attack handles the combo_count=0 case.
	elif is_dodging:
		new_anim = ANIM_DODGE
	elif is_dashing:
		new_anim = ANIM_DASH
	else: # Not attacking, not dodging - standard movement animations
		if not is_on_floor():
			new_anim = ANIM_JUMP
		elif abs(velocity.x) > 5.0 : # Use velocity for run, input for facing
			new_anim = ANIM_RUN
		else:
			new_anim = ANIM_IDLE

	if animated_sprite.animation != new_anim:
		animated_sprite.play(new_anim)

	# Sprite flipping logic
	if not is_dodging and not is_attacking: # Only flip from movement if not dodging or attacking
		if current_input_dir_x != 0:
			animated_sprite.flip_h = current_input_dir_x < 0
	# Flipping during attack start is handled in _handle_attack_input
	# Flipping during dodge start is handled in _start_dodge

# --- Timer Callbacks ---
func _on_DodgeDurationTimer_timeout() -> void:
	_end_dodge()

func _on_DodgeCooldownTimer_timeout() -> void:
	can_dodge = true

func _on_AttackCooldownTimer_timeout() -> void:
	can_attack_from_neutral = true
	print("Player: Can start new attack sequence.")

func _on_ComboWindowTimer_timeout() -> void:
	# If combo window expires, it means m1 finished but m2 was not triggered.
	# Reset attack state, which will also start the main attack cooldown.
	if is_attacking and attack_combo_count == 1: # Was waiting for m2 after m1
		print("Player: M2 Combo Window timed out.")
		_reset_attack_state()

# --- Animation Signal Callback ---
func _on_AnimatedSprite_animation_finished() -> void:
	var finished_anim_name: StringName = animated_sprite.animation

	if finished_anim_name == ANIM_ATTACK_M1:
		if attack_combo_count == 1: # If m1 finished and we didn't already combo to m2
			combo_window_timer.start() # Open window for m2 input
			# Player is still "is_attacking" conceptually during this window
		# If attack_combo_count became 2 (m2 triggered during m1), m2 will play next; do nothing here.
		
	elif finished_anim_name == ANIM_ATTACK_M2 or finished_anim_name == ANIM_JUMP_ATTACK:
		_reset_attack_state() # End attack sequence after m2 or jumpAttack

	#elif finished_anim_name == ANIM_DODGE:
		# Dodge invulnerability is tied to DodgeDurationTimer, not animation length here.
