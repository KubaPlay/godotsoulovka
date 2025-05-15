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

	# Connect to the player's health_updated signal
	if player.is_connected("health_updated", Callable(self, "_on_player_health_updated")) == false:
		var error_code = player.connect("health_updated", Callable(self, "_on_player_health_updated"))
		if error_code != OK:
			printerr("PlayerHealthBar: Failed to connect to player's health_updated signal. Error: ", error_code)
		else:
			print("PlayerHealthBar: Connected to player's health_updated signal.")
	
	# Initial update of the health bar
	# Get current and max health directly if possible, or wait for first signal
	if player.has_method("get_current_health") and player.has_method("get_max_health"):
		max_value = player.get_max_health()
		value = player.get_current_health()
	elif player.current_health != null and player.max_health != null : # If direct access to vars is okay
		max_value = player.max_health
		value = player.current_health


# This function is called when the player's health_updated signal is emitted
func _on_player_health_updated(new_health: int, max_hp: int) -> void:
	max_value = float(max_hp) # ProgressBar expects float for max_value and value
	value = float(new_health)
	# print("Health bar updated: ", value, "/", max_value)
