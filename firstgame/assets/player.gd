extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -250.0
const ATTACK_MOVEMENT_SPEED_FACTOR = 0.25 # Ponecháme pro pozemní útoky
const DODGE_SPEED_FACTOR = 1.8
const DODGE_DURATION = 0.4
const COMBO_WINDOW_DURATION: float = 0.3
const DODGE_COOLDOWN_DURATION: float = 2.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var running: bool = false

var current_attack_name: String = "" # Bude obsahovat "m1", "m2", "jumpAttack"
var can_link_to_m2: bool = false # Jen pro pozemní combo m1->m2

var is_dodging: bool = false
@onready var dodge_timer: Timer = Timer.new()

var is_dodge_on_cooldown: bool = false
@onready var dodge_cooldown_timer: Timer = Timer.new()

@onready var sprite: AnimatedSprite2D = $Animace
@onready var combo_window_timer: Timer = Timer.new() # Pro pozemní m1->m2 combo

func _ready():
	# ... (kód _ready zůstává stejný jako v předchozí verzi)
	if not sprite:
		printerr("CHYBA: Node $Animace nenalezen!")
		return

	if not sprite.is_connected("animation_finished", Callable(self, "_on_Animace_animation_finished")):
		var error_code = sprite.connect("animation_finished", Callable(self, "_on_Animace_animation_finished"))
		if error_code == OK:
			print("DEBUG: Signál 'animation_finished' byl úspěšně programově připojen.")
		else:
			printerr("CHYBA: Nepodařilo se programově připojit signál 'animation_finished', kód chyby: ", error_code)

	combo_window_timer.name = "ComboWindowTimer"
	combo_window_timer.wait_time = COMBO_WINDOW_DURATION
	combo_window_timer.one_shot = true
	combo_window_timer.connect("timeout", Callable(self, "_on_ComboWindowTimer_timeout"))
	add_child(combo_window_timer)

	dodge_timer.name = "DodgeTimer"
	dodge_timer.wait_time = DODGE_DURATION
	dodge_timer.one_shot = true
	dodge_timer.connect("timeout", Callable(self, "_on_DodgeTimer_timeout"))
	add_child(dodge_timer)

	dodge_cooldown_timer.name = "DodgeCooldownTimer"
	dodge_cooldown_timer.wait_time = DODGE_COOLDOWN_DURATION
	dodge_cooldown_timer.one_shot = true
	dodge_cooldown_timer.connect("timeout", Callable(self, "_on_DodgeCooldownTimer_timeout"))
	add_child(dodge_cooldown_timer)

	print("DEBUG: _ready() dokončeno. Výchozí animace: idle")
	sprite.play("idle")


func _on_Animace_animation_finished():
	print("DEBUG_SIGNAL: Animace dokončena: '", sprite.animation, "'")
	var finished_anim = sprite.animation

	if finished_anim == current_attack_name and current_attack_name != "":
		if finished_anim == "m1": # Pozemní m1
			can_link_to_m2 = true
			combo_window_timer.start()
			print("DEBUG_SIGNAL: 'm1' skončila. Combo okno pro 'm2' otevřeno.")
			# current_attack_name NENÍ ještě ""
		elif finished_anim == "m2": # Pozemní m2
			print("DEBUG_SIGNAL: 'm2' skončila. Ukončuji pozemní útok.")
			current_attack_name = ""
			can_link_to_m2 = false
		elif finished_anim == "jumpAttack":
			print("DEBUG_SIGNAL: 'jumpAttack' skončil. Ukončuji vzdušný útok.")
			current_attack_name = "" # Vzdušný útok je u konce
			# Po skončení jumpAttack, pokud jsme stále ve vzduchu, animace by se měla přepnout na "jump"
			# To by měla zařídit logika v _physics_process -> ANIMACE
		# ... další specifické útoky
	elif finished_anim == "dodge":
		pass # Necháváme dodge_timer ukončit stav
	elif current_attack_name != "" and finished_anim != current_attack_name:
		print("DEBUG_SIGNAL: Varování! Skončila '", finished_anim, "', ale očekával se konec '", current_attack_name, "'. Resetuji útok.")
		current_attack_name = ""
		can_link_to_m2 = false


func _on_ComboWindowTimer_timeout(): # Jen pro pozemní m1->m2 combo
	if can_link_to_m2: # Pokud okno bylo pro m2
		print("DEBUG_TIMER: Combo okno pro 'm2' vypršelo. Ukončuji útok po 'm1'.")
		can_link_to_m2 = false
		if current_attack_name == "m1": # Byl to skutečně pozemní m1
			current_attack_name = ""


func _on_DodgeTimer_timeout():
	_end_dodge()

func _end_dodge():
	if is_dodging:
		print("DEBUG: Dodge aktivita ukončena.")
		is_dodging = false
		is_dodge_on_cooldown = true
		dodge_cooldown_timer.start()
		print("DEBUG: Dodge je nyní na cooldownu na ", DODGE_COOLDOWN_DURATION, "s.")


func _on_DodgeCooldownTimer_timeout():
	print("DEBUG: Dodge cooldown skončil.")
	is_dodge_on_cooldown = false


func _is_attacking() -> bool:
	return current_attack_name != ""

func can_perform_dodge() -> bool:
	return not _is_attacking() and not is_dodging and not is_dodge_on_cooldown

func can_perform_attack() -> bool: # Zda vůbec můžeme iniciovat nějaký útok
	return not is_dodging # Povolit útok i když `_is_attacking()` je true (pro combo)


func _physics_process(delta: float) -> void:
	if not sprite: return

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")

	# --- VSTUPY PRO AKCE ---
	if Input.is_action_just_pressed("dodge") and can_perform_dodge() and is_on_floor():
		is_dodging = true
		sprite.play("dodge")
		dodge_timer.start()
		var dodge_direction = direction if direction != 0 else (1 if not sprite.flip_h else -1)
		velocity.x = dodge_direction * SPEED * DODGE_SPEED_FACTOR
		print("DEBUG_INPUT: Dodge zahájen.")

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_attacking() and not is_dodging:
		velocity.y = JUMP_VELOCITY
		print("DEBUG_INPUT: Skok.")

	if Input.is_action_just_pressed("attack") and can_perform_attack():
		if not is_on_floor(): # VZDUŠNÝ ÚTOK
			if not _is_attacking(): # Může zahájit nový útok, pouze pokud už neútočí (jumpAttack není combo)
				print("DEBUG_INPUT: Vzdušný útok. Hraji: 'jumpAttack'.")
				current_attack_name = "jumpAttack"
				sprite.play("jumpAttack")
				# Pohyb během jumpAttack - obvykle chceme zachovat momentum nebo mírně upravit
				# velocity.x *= 0.8 # Příklad: lehké zpomalení ve vzduchu
				can_link_to_m2 = false # Vzdušný útok není součástí m1->m2 comba
		else: # POZEMNÍ ÚTOK
			if not _is_attacking(): # Nový pozemní útok m1
				print("DEBUG_INPUT: Pozemní útok. Hraji: 'm1'.")
				current_attack_name = "m1"
				sprite.play("m1")
				can_link_to_m2 = false # Reset pro případné combo
				if not combo_window_timer.is_stopped(): combo_window_timer.stop()
				velocity.x = direction * SPEED * ATTACK_MOVEMENT_SPEED_FACTOR # Omezený pohyb
			elif current_attack_name == "m1" and can_link_to_m2: # Pozemní combo m1 -> m2
				print("DEBUG_INPUT: Pozemní combo. Hraji: 'm2'.")
				current_attack_name = "m2"
				sprite.play("m2")
				can_link_to_m2 = false # Spotřebováno
				if not combo_window_timer.is_stopped(): combo_window_timer.stop()
				velocity.x = direction * SPEED * ATTACK_MOVEMENT_SPEED_FACTOR


	# --- OVLÁDÁNÍ POHYBU A OTÁČENÍ ---
	if not _is_attacking() and not is_dodging: # Běžný pohyb a otáčení
		running = (direction != 0)
		if direction > 0: sprite.flip_h = false
		elif direction < 0: sprite.flip_h = true
		
		if direction != 0: velocity.x = direction * SPEED
		else: velocity.x = move_toward(velocity.x, 0, SPEED)
	elif is_dodging:
		# Pohyb během dodge je už nastaven. Zde případně postupné brzdění.
		pass
	elif _is_attacking(): # Pohyb během útoku
		if is_on_floor(): # Během pozemního útoku
			if direction != 0: velocity.x = direction * SPEED * ATTACK_MOVEMENT_SPEED_FACTOR
			else: velocity.x = move_toward(velocity.x, 0, SPEED * ATTACK_MOVEMENT_SPEED_FACTOR * 1.5)
		else: # Během vzdušného útoku ("jumpAttack")
			# Zachováme momentum nebo jemně upravíme (velocity.x by se nemělo nastavovat na 0)
			if direction != 0: velocity.x = move_toward(velocity.x, direction * SPEED * 0.7, SPEED * 0.3 * delta)


	# --- SPRÁVA ANIMACÍ (POHYBOVÝCH) ---
	# Tato sekce se aktivuje POUZE pokud neprobíhá žádný útok ani dodge.
	if not _is_attacking() and not is_dodging:
		if not is_on_floor():
			if sprite.animation != "jump": # Předchozí problém mohl být zde, pokud "jumpAttack" skončil
											# a tato sekce se hned pokusila přehrát "jump"
											# nad nedokončeným "jumpAttack".
											# Nově se current_attack_name po "jumpAttack" vyčistí.
				sprite.play("jump")
		elif running:
			if sprite.animation != "run":
				sprite.play("run")
		else:
			if sprite.animation != "idle":
				sprite.play("idle")
	elif _is_attacking() and not is_on_floor() and current_attack_name != "jumpAttack":
		# Pokud útočíme (např. m1/m2) a spadneme ze vzduchu, NEBO
		# pokud jsme ve vzduchu, neútočíme aktivně vzdušným útokem, ale útok ještě neskončil (m1 combo okno)
		# Toto je komplexnější stav, prozatím, pokud není jumpAttack, a jsme ve vzduchu + útočíme -> hraj "jump"
		# Lépe by bylo mít specifické "fall_attack" animace nebo přerušit pozemní útok.
		# Pro jednoduchost nyní, pokud útočný stav je aktivní, ale není to "jumpAttack" a jsme ve vzduchu,
		# nepřepisujeme animaci, necháme útok doběhnout. Logika pro `sprite.play("jump")` je výše.
		pass
	# else if is_dodging: - animace pro dodge se spustí při vstupu a tato sekce je neaktivní.


	move_and_slide()
