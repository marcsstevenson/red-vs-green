extends Node2D

# Access the Globals script as a resource
const Globals = preload("res://Globals.gd")
# Preload scene for reproduction
const GREEN_DOT_SCENE = preload("res://green_dot.tscn")

func _draw():
	var center = Vector2(0, 0) # Draw at the node's local origin
	var radius = 4			# Example size; adjust as needed
	var green = Color(0, 1, 0, 1)
	draw_circle(center, radius, green)

var lifetime = 0
var wander_direction = Vector2.ZERO
var direction_change_timer = 0.0
var direction_change_interval = 2.0  # Change direction every 2 seconds
var target_search_timer = 0.0  # Timer for throttling target searches
var last_grid_pos = Vector2i.ZERO  # Track grid position for spatial optimization
var reproduction_time = 0.0  # Individual reproduction time with variation

func _ready():
	add_to_group("greens")
	# Initialize with a random direction
	wander_direction = Vector2(randf() - 0.5, randf() - 0.5).normalized()

	# Set individual reproduction time with ±2 second variation
	reproduction_time = Globals.GREEN_LIFESPAN + (randf() - 0.5) * 4.0  # ±2 seconds

	# Add to spatial grid
	Globals.add_to_spatial_grid(self, "greens")
	last_grid_pos = Globals.get_grid_coords(global_position)

func _process(delta):
	lifetime += delta
	target_search_timer += delta

	# Update spatial grid position if moved significantly
	var current_grid_pos = Globals.get_grid_coords(global_position)
	if current_grid_pos != last_grid_pos:
		Globals.remove_from_spatial_grid(self, "greens")
		Globals.add_to_spatial_grid(self, "greens")
		last_grid_pos = current_grid_pos

	# Check for reproduction using individual reproduction time with variation
	if lifetime > reproduction_time:
		survive()

	# Only search for threats periodically, not every frame
	var threat = null
	if target_search_timer >= Globals.TARGET_SEARCH_INTERVAL:
		threat = get_nearest_red()
		target_search_timer = 0.0

	if threat:
		var dir = (global_position - threat.global_position).normalized()
		global_position += dir * Globals.GREEN_SPEED * delta
	else:
		wander(delta)

func get_nearest_red():
	# Use spatial partitioning for much faster searches with large numbers
	var nearby_reds = Globals.get_nearby_nodes(global_position, "reds", Globals.GREEN_VISION)
	var nearest = null
	var min_dist_squared = Globals.GREEN_VISION_SQUARED

	for red in nearby_reds:
		if not is_instance_valid(red):
			continue
		var dist_squared = global_position.distance_squared_to(red.global_position)
		if dist_squared < min_dist_squared:
			min_dist_squared = dist_squared
			nearest = red
	return nearest

func survive():
	# Reproduce using preloaded scene instead of duplicate for better performance
	var new_green = GREEN_DOT_SCENE.instantiate()
	get_parent().add_child(new_green)
	new_green.global_position = global_position + Vector2(randf()-0.5, randf()-0.5)*Globals.SPAWN_DISTANCE
	lifetime = 0

func _exit_tree():
	# Clean up spatial grid when node is removed
	Globals.remove_from_spatial_grid(self, "greens")

func wander(delta):
	var result = Globals.wander_with_boundaries(self, wander_direction, direction_change_timer, delta)
	wander_direction = result["wander_direction"]
	direction_change_timer = result["direction_change_timer"]
