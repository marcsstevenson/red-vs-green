extends Node2D

var target = null
var reproduce_timer = null
var wander_direction = Vector2.ZERO
var direction_change_timer = 0.0
var target_search_timer = 0.0  # Timer for throttling target searches
var starvation_timer = 0.0  # Timer for tracking time without eating
var last_grid_pos = Vector2i.ZERO  # Track grid position for spatial optimization

# Access the Globals script as a resource
const Globals = preload("res://Globals.gd")
# Preload scene for reproduction
const RED_DOT_SCENE = preload("res://red_dot.tscn")

func _ready():
	# Add this red dot to the "reds" group so green dots can detect it
	add_to_group("reds")

	# Initialize with a random direction
	wander_direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()

	# Add to spatial grid
	Globals.add_to_spatial_grid(self, "reds")
	last_grid_pos = Globals.get_grid_coords(global_position)

	# Create and configure the timer
	reproduce_timer = Timer.new()
	reproduce_timer.wait_time = Globals.RED_REPRODUCE_DELAY
	reproduce_timer.one_shot = true
	reproduce_timer.timeout.connect(_on_timer_timeout)
	add_child(reproduce_timer)

func _draw():
	var center = Vector2(0, 0) # Draw at the node's local origin
	var radius = 8			# Example size; adjust as needed

	var color: Color

	# Check if currently reproducing (timer is running)
	if reproduce_timer and not reproduce_timer.is_stopped():
		# Yellow while reproducing
		color = Color(1, 1, 0, 1)
	else:
		# Calculate starvation progress (0.0 = just fed, 1.0 = about to starve)
		var starvation_progress = starvation_timer / Globals.RED_STARVATION_TIME
		starvation_progress = clamp(starvation_progress, 0.0, 1.0)

		# Interpolate from bright red (fed) to black (starving)
		var red_intensity = 1.0 - starvation_progress
		color = Color(red_intensity, 0, 0, 1)

	draw_circle(center, radius, color)

func _process(delta):
	target_search_timer += delta
	starvation_timer += delta  # Track time without eating

	# Update spatial grid position if moved significantly
	var current_grid_pos = Globals.get_grid_coords(global_position)
	if current_grid_pos != last_grid_pos:
		Globals.remove_from_spatial_grid(self, "reds")
		Globals.add_to_spatial_grid(self, "reds")
		last_grid_pos = current_grid_pos

	# Trigger visual update as starvation progresses
	queue_redraw()

	# Check for starvation
	if starvation_timer >= Globals.RED_STARVATION_TIME:
		starve()
		return

	# Only search for targets periodically, not every frame
	if not target and target_search_timer >= Globals.TARGET_SEARCH_INTERVAL:
		get_nearest_green()
		target_search_timer = 0.0

	# Check if current target is still valid
	if target and not is_instance_valid(target):
		target = null

	if target:
		# Use global_position to get actual world coordinates
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * Globals.RED_SPEED * delta
		# Use distance_squared for faster comparison
		if global_position.distance_squared_to(target.global_position) < Globals.EAT_DISTANCE_SQUARED:
			eat(target)
	else:
		wander(delta)

func wander(delta):
	var result = Globals.wander_with_boundaries(self, wander_direction, direction_change_timer, delta)
	wander_direction = result["wander_direction"]
	direction_change_timer = result["direction_change_timer"]

func get_nearest_green():
	# Use spatial partitioning for much faster searches with large numbers
	var nearby_greens = Globals.get_nearby_nodes(global_position, "greens", Globals.RED_VISION)
	var red_vision_squared = Globals.RED_VISION_SQUARED
	var closest_distance_squared = red_vision_squared
	target = null

	for green in nearby_greens:
		if not is_instance_valid(green):
			continue
		var dist_squared = global_position.distance_squared_to(green.global_position)
		if dist_squared < closest_distance_squared:
			closest_distance_squared = dist_squared
			target = green

func eat(green):
	# Remove green from spatial grid before freeing
	Globals.remove_from_spatial_grid(green, "greens")
	green.queue_free()
	target = null
	starvation_timer = 0.0  # Reset starvation timer when eating
	queue_redraw()  # Immediately update visual to show reproduction color
	reproduce_timer.start() # Use the programmatically created timer
	set_process(false)

func starve():
	# Remove from spatial grid before dying
	Globals.remove_from_spatial_grid(self, "reds")
	# Red dot dies from starvation
	queue_free()

func _on_timer_timeout():
	# Reproduce using preloaded scene instead of duplicate for better performance
	var new_red = RED_DOT_SCENE.instantiate()
	get_parent().add_child(new_red)
	new_red.global_position = global_position + Vector2(randf()-0.5, randf()-0.5)*Globals.SPAWN_DISTANCE
	queue_redraw()  # Update visual to show normal color after reproduction
	set_process(true)
