extends CharacterBody2D

# Pohybové vlastnosti
const MOVE_SPEED: float = 50.0
const ACCELERATION: float = 500.0
const FRICTION: float = 600.0

# Detekční a útočné vlastnosti
var player: CharacterBody2D = null
var player_in_detection_range: bool = false
var player_in_attack_range: bool = false

var is_attacking: bool = false
const ATTACK_DAMAGE: int = 10
const ATTACK_COOLDOWN: float = 2.0
var can_attack: bool = true

# ----- ZDE JE PRAVDĚPODOBNÁ OPRAVA -----
# Ujistěte se, že názvy nodů za znakem '$' přesně odpovídají názvům nodů ve vaší scéně nepřítele!
# A typy (za dvojtečkou) odpovídají skutečným typům těchto nodů.

@onready var sprite: AnimatedSprite2D = $ActionAnimationPlayer # Sprite node by měl být typu AnimatedSprite2D
@onready var detection_range_area: Area2D = $DetectionRange # Toto by mělo být Area2D
@onready var attack_range_area: Area2D = $AttackRange # Toto by mělo být Area2D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer # Toto by mělo být Timer
@onready var enemy_attack_hitbox: Area2D = $EnemyAttackHitbox # Pokud máte, je to Area2D
@onready var action_anim_player: AnimationPlayer = $AnimationPlayer # Toto by mělo být AnimationPlayer

# Stavy pro jednoduchou AI
enum State { IDLE, CHASING, ATTACKING }
var current_state: State = State.IDLE

func _ready() -> void:
	# Ověření, zda nody existují (dobrá praxe pro ladění)
	if not sprite:
		printerr("CHYBA v Enemy: Node $Sprite nenalezen nebo není typu AnimatedSprite2D!")
		return # Ukonči, aby se zabránilo dalším chybám
	if not detection_range_area:
		printerr("CHYBA v Enemy: Node $DetectionRange nenalezen nebo není typu Area2D!")
		return
	if not attack_range_area:
		printerr("CHYBA v Enemy: Node $AttackRange nenalezen nebo není typu Area2D!")
		return
	if not attack_cooldown_timer:
		printerr("CHYBA v Enemy: Node $AttackCooldownTimer nenalezen nebo není typu Timer!")
		return
	# Tyto jsou volitelné, takže kontrola může být mírnější
	if not enemy_attack_hitbox:
		print("POZNÁMKA v Enemy: Node $EnemyAttackHitbox nenalezen. Hitbox útoku nebude fungovat.")
	if not action_anim_player:
		print("POZNÁMKA v Enemy: Node $ActionAnimationPlayer nenalezen. Animace hitboxu nebudou fungovat.")


	# Připojení signálů z Area2D pro detekci
	detection_range_area.body_entered.connect(_on_DetectionRange_body_entered)
	detection_range_area.body_exited.connect(_on_DetectionRange_body_exited)
	attack_range_area.body_entered.connect(_on_AttackRange_body_entered)
	attack_range_area.body_exited.connect(_on_AttackRange_body_exited)

	# Nastavení timeru pro cooldown útoku
	attack_cooldown_timer.wait_time = ATTACK_COOLDOWN
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.timeout.connect(_on_AttackCooldownTimer_timeout)

	sprite.animation_finished.connect(_on_Sprite_animation_finished)

	if enemy_attack_hitbox:
		enemy_attack_hitbox.monitoring = false
		if not enemy_attack_hitbox.is_connected("body_entered", Callable(self, "_on_EnemyAttackHitbox_body_entered")):
			enemy_attack_hitbox.body_entered.connect(_on_EnemyAttackHitbox_body_entered)
	else:
		printerr("CHYBA v Enemy: Node $EnemyAttackHitbox nenalezen! Útoky nebudou fungovat.")
		
	if not action_anim_player:
		printerr("CHYBA v Enemy: Node $AnimationPlayer nenalezen! Animace hitboxu nebudou fungovat.")

	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not sprite: return # Pokud sprite není načten, nic nedělat
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.CHASING:
			_state_chasing(delta)
		State.ATTACKING:
			_state_attacking(delta)

	move_and_slide()
	_update_animation()

func _on_EnemyAttackHitbox_body_entered(body: Node2D) -> void:
	print("asdasdasdasdsadasdas")
	if body.is_in_group("player_character"): # Make sure player is in this group too
		print(name + " zasáhl hráče!")
		print("ENEMY: Hitbox collided with player_character: ", body.name) 
		if body.has_method("take_damage"):
			body.take_damage(ATTACK_DAMAGE) # ATTACK_DAMAGE is defined in your enemy script
		
		if enemy_attack_hitbox:
			enemy_attack_hitbox.monitoring = false

func _state_idle(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * _delta)
	if player_in_detection_range and player:
		current_state = State.CHASING


func _state_chasing(delta: float) -> void:
	if not player_in_detection_range or not player:
		current_state = State.IDLE
		return

	if player_in_attack_range and can_attack:
		# Přesun logiky útoku přímo sem pro jasnost
		current_state = State.ATTACKING
		is_attacking = true
		can_attack = false
		sprite.play("m1") # Předpokládáme animaci útoku "m1"
		if player: # Otočení před útokem
			sprite.flip_h = (player.global_position.x < global_position.x)
		print(name + " útočí (ze stavu CHASING)!")
		if action_anim_player: # Pokud existuje, spustí animaci hitboxu
			action_anim_player.play("EnemyAttackHitbox.monitoring") # Ujistěte se, že máte tuto animaci
		return # Po zahájení útoku již nepokračuj v tomto framu s logikou CHASING

	var direction_to_player = (player.global_position - global_position).normalized()
	velocity = velocity.move_toward(direction_to_player * MOVE_SPEED, ACCELERATION * delta)
	sprite.flip_h = (direction_to_player.x < 0) # Zjednodušené otočení


func _state_attacking(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * _delta)
	# Útok probíhá. Čeká se na _on_Sprite_animation_finished.


# _perform_attack() může být odstraněna, pokud je logika útoku přímo ve _state_chasing
# nebo pokud chcete útok spouštět i z jiných stavů. Prozatím ji nechávám zakomentovanou.
# func _perform_attack() -> void:
# 	if not can_attack or is_attacking:
# 		return
# 	is_attacking = true
# 	can_attack = false
# 	sprite.play("m1")
# 	if player:
# 		sprite.flip_h = (player.global_position.x < global_position.x)
# 	print(name + " útočí!")
# 	if action_anim_player:
# 		action_anim_player.play("enemy_m1_hitbox")


func _update_animation() -> void:
	if is_attacking:
		return # Animace útoku je řízena jinde
	
	if velocity.length_squared() > 5.0 * 5.0: # Efektivnější kontrola než .length()
		if sprite.animation != "run":
			sprite.play("run")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")


func _on_DetectionRange_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_character"):
		player = body as CharacterBody2D
		player_in_detection_range = true
		print(name + ": Hráč v detekčním dosahu!")


func _on_DetectionRange_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_detection_range = false
		# player = null # Resetovat hráče, pokud je mimo detekci a attack range
		if not player_in_attack_range: player = null
		current_state = State.IDLE
		print(name + ": Hráč opustil detekční dosah.")


func _on_AttackRange_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_character"): # Pro případ, že by hráč vstoupil rovnou do AttackRange
		if not player: player = body as CharacterBody2D
		player_in_attack_range = true
		print(name + ": Hráč v útočném dosahu!")
		if can_attack and (current_state == State.CHASING or current_state == State.IDLE): # Může zaútočit z CHASING nebo i když stojí a hráč přijde
			current_state = State.ATTACKING
			is_attacking = true # Důležité nastavit před přehráním animace
			can_attack = false
			sprite.play("m1")
			if player: sprite.flip_h = (player.global_position.x < global_position.x)
			print(name + " útočí (z _on_AttackRange_body_entered)!")
			if action_anim_player: action_anim_player.play("EnemyAttackHitbox.monitoring")


func _on_AttackRange_body_exited(body: Node2D) -> void:
	if body == player:
		player_in_attack_range = false
		print(name + ": Hráč opustil útočný dosah.")
		# Pokud neútočil a hráč odešel z útočného dosahu, ale je stále v detekčním, přejdi na CHASING
		if not is_attacking and player_in_detection_range:
			current_state = State.CHASING


func _on_AttackCooldownTimer_timeout() -> void:
	can_attack = true
	print(name + ": Cooldown útoku skončil.")
	# Pokud je hráč stále v attack range, můžeme zkusit zaútočit znovu
	if player_in_attack_range and player and current_state != State.ATTACKING: # A pokud už neútočíme z nějakého jiného důvodu
		current_state = State.ATTACKING
		is_attacking = true
		can_attack = false # Ihned znovu na cooldown
		sprite.play("m1")


		if player: sprite.flip_h = (player.global_position.x < global_position.x)
		print(name + " útočí (po cooldownu, hráč stále blízko)!")
		if action_anim_player: action_anim_player.play("EnemyAttackHitbox.monitoring")


func _on_Sprite_animation_finished() -> void:
	if is_attacking and (sprite.animation == "m1"): # Ujistěte se, že název "m1" odpovídá
		print(name + ": Animace útoku ('m1') dokončena.")
		is_attacking = false
		attack_cooldown_timer.start() # Spusť cooldown

		if enemy_attack_hitbox and action_anim_player and action_anim_player.current_animation == "EnemyAttackHitbox.monitoring":
			# Není standardní, ale pokud chcete hitbox deaktivovat zde (lepší je v animaci hitboxu)
			pass # enemy_attack_hitbox.monitoring = false

		# Rozhodnutí po útoku
		if player_in_attack_range and player and can_attack: # A můžeme znovu útočit
			# Okamžitý další útok, pokud hráč neunikl a cooldown to dovolí
			# (can_attack by zde mělo být false kvůli cooldownu, ale pokud by cooldown byl krátký)
			# Raději přejít do CHASING a nechat logiku tam rozhodnout o dalším útoku
			current_state = State.CHASING
		elif player_in_detection_range and player:
			current_state = State.CHASING
		else:
			current_state = State.IDLE
			player = null # Pokud není v žádném dosahu, zapomeň na něj


# Hitbox metoda - MUSÍTE SI BÝT JISTÍ, ŽE JE TENTO SIGNÁL PŘIPOJEN V EDITORU
# NEBO PROGRAMOVĚ A ŽE collision_layer/mask JE SPRÁVNĚ
