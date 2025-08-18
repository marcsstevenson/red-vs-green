# Globals.gd

const RED_SPEED = 100
const GREEN_SPEED = 80
const RED_VISION = 50
const GREEN_VISION = 30
const SPAWN_DISTANCE = 12
const EAT_DISTANCE = 10  # Distance at which red dots can eat green dots (touching)
const RED_REPRODUCE_DELAY = 4
const GREEN_LIFESPAN = 10
const WANDER_AMOUNT = 15
const RED_STARVATION_TIME = 20.0  # Red dots starve after 5 seconds without eating

# Performance optimization constants
const TARGET_SEARCH_INTERVAL = 0.15  # Search for targets every 0.15 seconds instead of every frame
const RED_VISION_SQUARED = RED_VISION * RED_VISION  # Precomputed for faster distance checks
const GREEN_VISION_SQUARED = GREEN_VISION * GREEN_VISION
const EAT_DISTANCE_SQUARED = EAT_DISTANCE * EAT_DISTANCE

# Spatial partitioning for large numbers of dots
const GRID_SIZE = 100  # Size of each spatial grid cell
static var spatial_grid = {}  # Grid for spatial partitioning
static var viewport_size = Vector2.ZERO

# Initialize spatial grid
static func init_spatial_grid(screen_size: Vector2):
	viewport_size = screen_size
	spatial_grid.clear()

# Get grid coordinates for a position
static func get_grid_coords(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / GRID_SIZE), int(pos.y / GRID_SIZE))

# Add node to spatial grid
static func add_to_spatial_grid(node: Node2D, group_name: String):
	var grid_pos = get_grid_coords(node.global_position)
	var key = str(grid_pos) + "_" + group_name
	if not spatial_grid.has(key):
		spatial_grid[key] = []
	spatial_grid[key].append(node)

# Remove node from spatial grid
static func remove_from_spatial_grid(node: Node2D, group_name: String):
	var grid_pos = get_grid_coords(node.global_position)
	var key = str(grid_pos) + "_" + group_name
	if spatial_grid.has(key):
		spatial_grid[key].erase(node)
		if spatial_grid[key].is_empty():
			spatial_grid.erase(key)

# Get nearby nodes using spatial partitioning
static func get_nearby_nodes(pos: Vector2, group_name: String, search_radius: float) -> Array:
	var nearby_nodes = []
	var grid_radius = int(search_radius / GRID_SIZE) + 1
	var center_grid = get_grid_coords(pos)

	# Check surrounding grid cells
	for x in range(center_grid.x - grid_radius, center_grid.x + grid_radius + 1):
		for y in range(center_grid.y - grid_radius, center_grid.y + grid_radius + 1):
			var key = str(Vector2i(x, y)) + "_" + group_name
			if spatial_grid.has(key):
				nearby_nodes.append_array(spatial_grid[key])

	return nearby_nodes

# Shared wander function for both red and green dots
static func wander_with_boundaries(node: Node2D, wander_direction: Vector2, direction_change_timer: float, delta: float) -> Dictionary:
	# Get viewport bounds
	var screen_size = node.get_viewport().get_visible_rect().size
	var margin = 10  # Small margin from edges

	# Check if we're near boundaries and adjust direction
	if node.global_position.x < margin and wander_direction.x < 0:
		wander_direction.x = abs(wander_direction.x)  # Bounce right
	elif node.global_position.x > screen_size.x - margin and wander_direction.x > 0:
		wander_direction.x = -abs(wander_direction.x)  # Bounce left

	if node.global_position.y < margin and wander_direction.y < 0:
		wander_direction.y = abs(wander_direction.y)  # Bounce down
	elif node.global_position.y > screen_size.y - margin and wander_direction.y > 0:
		wander_direction.y = -abs(wander_direction.y)  # Bounce up

	# Normalize direction after potential boundary adjustments
	wander_direction = wander_direction.normalized()

	# Change direction slightly every frame (±5 degrees) only if not bouncing
	if node.global_position.x > margin and node.global_position.x < screen_size.x - margin and node.global_position.y > margin and node.global_position.y < screen_size.y - margin:
		var angle_change = (randf() - 0.5) * PI * (5.0 / 180.0) * 2  # ±5 degrees in radians
		var current_angle = wander_direction.angle()
		var new_angle = current_angle + angle_change
		wander_direction = Vector2(cos(new_angle), sin(new_angle))

	# Move the node
	node.global_position += wander_direction * WANDER_AMOUNT * delta

	# Return updated values
	return {
		"wander_direction": wander_direction,
		"direction_change_timer": direction_change_timer + delta
	}
