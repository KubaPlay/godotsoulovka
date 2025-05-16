extends ProgressBar

# We need a reference to the player to connect to their signals.
# It's best if the player is in a group, e.g., "player_character".
# Add your player to the "player_character" group via the Node > Groups tab in the Inspector.

func _ready() -> void:
	# Wait a frame for the player to be ready, or use call_deferred
	call_deferred("_connect_to_player_signals")

func _connect_to_player_signals() -> void:
	# Find the player node. Make sure your player is in the "player_character" group.
	# Or, if you have a global singleton for player access, use that.
	var player_nodes = get_tree().get_nodes_in_group("player_character")
	if player_nodes.is_empty():
		printerr("PlayerHealthBar: Could not find player node in group 'player_character'!")
		return

	var player = player_nodes[0] # Get the first player found

	# Ensure 'player' is a valid Node before proceeding
	if not is_instance_valid(player):
		printerr("PlayerHealthBar: Player node found in group 'player_character' is not valid!")
		return

	# Connect to the player's health_updated signal
	# Simplified the connection check
	if not player.is_connected("health_updated", Callable(self, "_on_player_health_updated")):
		var error_code = player.connect("health_updated", Callable(self, "_on_player_health_updated"))
		if error_code != OK:
			printerr("PlayerHealthBar: Failed to connect to player's health_updated signal. Error: ", error_code, " (Is 'player' the correct node and does it have this signal?)")
		else:
			print("PlayerHealthBar: Connected to player's health_updated signal.")
	
	# Initial update of the health bar
	# Get current and max health directly if possible, or wait for first signal
	if player.has_method("get_current_health") and player.has_method("get_max_health"):
		max_value = player.get_max_health()
		value = player.get_current_health()
		print("PlayerHealthBar: Initialized using get_current_health()/get_max_health().")
	# Changed condition to safely check for property existence on 'player'
	elif "current_health" in player and "max_health" in player:
		# Ensure the properties are not null before trying to use them,
		# though 'in' check often suffices if properties are guaranteed to be non-null when they exist.
		if player.current_health != null and player.max_health != null:
			max_value = player.max_health
			value = player.current_health
			print("PlayerHealthBar: Initialized using direct access to current_health/max_health properties.")
		else:
			printerr("PlayerHealthBar: Player node has current_health/max_health properties, but they are null. Health bar not initialized.")
	else:
		# This message will now appear if neither methods nor direct properties are found
		printerr("PlayerHealthBar: Player node in group 'player_character' does not have 'get_current_health'/'get_max_health' methods nor 'current_health'/'max_health' properties for initial setup. Health bar will update on first signal.")


# This function is called when the player's health_updated signal is emitted
func _on_player_health_updated(new_health: int, max_hp: int) -> void:
	max_value = float(max_hp) # ProgressBar expects float for max_value and value
	value = float(new_health)
	# print("Health bar updated: ", value, "/", max_value)
