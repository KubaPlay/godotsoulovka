extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -250.0
const ATTACK_MOVEMENT_SPEED_FACTOR = 0.25 # Jak rychle se lze pohybovat během pozemního útoku (0.0 = žádný, 1.0 = plná rychlost)

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var running: bool = false
# Proměnná jumping se může odstranit, pokud ji nepoužíváte jinde,
# protože stav ve vzduchu se určuje primárně přes `not is_on_floor()`
# var jumping: bool = false

var current_attack_name: String = ""
var can_link_to_m2: bool = false

@onready var sprite: AnimatedSprite2D = $Animace
@onready var combo_window_timer: Timer = Timer.new()

const COMBO_WINDOW_DURATION: float = 0.3

func _ready():
	# ... (kód _ready zůstává stejný jako v předchozí odpovědi)
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

	print("DEBUG: _ready() dokončeno. Výchozí animace: idle")
	sprite.play("idle")


func _on_Animace_animation_finished():
	# ... (kód _on_Animace_animation_finished zůstává stejný)
	print("DEBUG_SIGNAL: Animace dokončena: '", sprite.animation, "'")
	print("DEBUG_SIGNAL: Aktuální útok byl: '", current_attack_name, "'")

	var finished_anim = sprite.animation

	if finished_anim == current_attack_name:
		if finished_anim == "m1":
			can_link_to_m2 = true
			combo_window_timer.start()
			print("DEBUG_SIGNAL: 'm1' skončila. Combo okno pro 'm2' otevřeno.")
		elif finished_anim == "m2":
			print("DEBUG_SIGNAL: 'm2' skončila. Ukončuji útok.")
			current_attack_name = ""
			can_link_to_m2 = false
	elif current_attack_name != "":
		print("DEBUG_SIGNAL: Skončila animace '", finished_anim, "', ale očekával se konec '", current_attack_name, "'. Resetuji útok.")
		current_attack_name = ""
		can_link_to_m2 = false


func _on_ComboWindowTimer_timeout():
	# ... (kód _on_ComboWindowTimer_timeout zůstává stejný)
	if can_link_to_m2:
		print("DEBUG_TIMER: Combo okno pro 'm2' vypršelo. Ukončuji útok po 'm1'.")
		can_link_to_m2 = false
		if current_attack_name == "m1":
			current_attack_name = ""


func _is_attacking() -> bool:
	return current_attack_name != ""


func _physics_process(delta: float) -> void:
	if not sprite: return

	# GRAVITACE - aplikuje se vždy, i během útoku
	if not is_on_floor():
		velocity.y += gravity * delta

	# SKÁKÁNÍ
	# `_is_attacking()` kontrola zůstává, aby se nedalo skočit uprostřed útoku (běžné chování)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_attacking():
		velocity.y = JUMP_VELOCITY
		# jumping = true # nepotřebujeme nutně, sprite pro skok se řídí is_on_floor()
		print("DEBUG: Skok")

	# if is_on_floor(): # Tuto část už explicitně nepotřebujeme pro jumping flag
	# 	jumping = false


	# POHYB (VSTUP OD HRÁČE)
	var direction := Input.get_axis("move_left", "move_right")

	# ZPRACOVÁNÍ VSTUPU PRO ÚTOK - nyní možné i ve vzduchu
	if Input.is_action_just_pressed("attack"): # Odstraněna podmínka is_on_floor()
		if not _is_attacking():
			print("DEBUG_INPUT: Detekován vstup pro útok. Zahajuji 'm1'.")
			current_attack_name = "m1"
			sprite.play("m1")
			can_link_to_m2 = false
			if not combo_window_timer.is_stopped():
				combo_window_timer.stop()
			
			# Ovlivnění pohybu při zahájení útoku
			if not is_on_floor():
				# Ve vzduchu chceme často menší dopad na horizontální rychlost
				# velocity.x *= 0.5 # Např. zpomalit o 50%
				pass # Nebo nechat hybnost jak je
			else:
				# Na zemi můžeme pohyb omezit více, ale ne nutně na 0
				velocity.x = direction * SPEED * ATTACK_MOVEMENT_SPEED_FACTOR # Pro malé klouzání
				# velocity.x = 0 # Pro úplné zastavení

		elif current_attack_name == "m1" and can_link_to_m2:
			print("DEBUG_INPUT: Detekován vstup pro combo. Zahajuji 'm2'.")
			current_attack_name = "m2"
			sprite.play("m2")
			can_link_to_m2 = false
			if not combo_window_timer.is_stopped():
				combo_window_timer.stop()

			if not is_on_floor():
				pass # Podobně pro m2 ve vzduchu
			else:
				velocity.x = direction * SPEED * ATTACK_MOVEMENT_SPEED_FACTOR
				# velocity.x = 0


	# OTOČENÍ SPRITE
	# Otočení povoleno, POKUD NEÚTOČÍME. Během útoku si sprite drží směr, kterým útok začal.
	# Výjimka: pokud útočíme a jsme ve vzduchu a měníme směr, můžeme zvážit otočení,
	# ale pro jednoduchost to zde neimplementujeme.
	if not _is_attacking():
		if direction > 0:
			sprite.flip_h = false
		elif direction < 0:
			sprite.flip_h = true

	# HORIZONTÁLNÍ POHYB
	if _is_attacking():
		# Pohyb během útoku
		if is_on_floor():
			# Povolíme omezený pohyb podle 'direction' během pozemního útoku
			if direction != 0:
				velocity.x = direction * SPEED * ATTACK_MOVEMENT_SPEED_FACTOR
			else:
				# Pokud hráč nedrží směr, pomalu brzdit
				velocity.x = move_toward(velocity.x, 0, SPEED * ATTACK_MOVEMENT_SPEED_FACTOR * 2 * delta) # Rychlejší brzdění
		else:
			# Ve vzduchu necháme hráče ovlivňovat směr (air control),
			# ale rychlost bude daná spíše skokem a gravitací.
			# Můžeme aplikovat standardní air control, pokud ho máte implementovaný.
			# Pro jednoduchost zde můžeme nechat velocity.x být ovlivněno předchozími akcemi,
			# nebo přidat malý vliv direction:
			if direction != 0:
				velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * 0.5 * delta) # Pomalá změna směru ve vzduchu
			# Pokud nemáte air control, velocity.x bude pokračovat z předchozího pohybu
	else:
		# Normální pohyb, když neútočíme
		running = (direction != 0) # Nastav running pouze když neútočíme a hýbeme se
		if direction != 0:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)


	# ANIMACE
	# Tato sekce se nyní stará primárně o animace pohybu a skoku.
	# Útočné animace se spouštějí POUZE v sekci ZPRACOVÁNÍ VSTUPU PRO ÚTOK.
	if not _is_attacking():
		if not is_on_floor():
			if sprite.animation != "jump": # A není to jiná útočná animace, která by mohla běžet (neměla by)
				sprite.play("jump")
		elif running:
			if sprite.animation != "run":
				sprite.play("run")
		else: # Stojíme
			if sprite.animation != "idle":
				sprite.play("idle")
	# else:
		# Pokud _is_attacking(), útočná animace by měla hrát.
		# Kontrolu `if sprite.animation != current_attack_name: sprite.play(current_attack_name)`
		# přidávejte jen pokud máte problémy s přerušením útočných animací.
		# Správně by se neměly přerušovat, pokud není jiná logika, která by to způsobila.

	move_and_slide()
