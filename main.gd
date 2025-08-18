extends Node2D

# Preload scenes directly here to avoid circular dependencies
const RED_DOT_SCENE = preload("res://red_dot.tscn")
const GREEN_DOT_SCENE = preload("res://green_dot.tscn")
const Globals = preload("res://Globals.gd")

func spawn_agents():
	var num_reds = 10		# How many to start with
	var num_greens = 30	 # How many to start with
	var screen_size = get_viewport().get_visible_rect().size

	# Initialize spatial partitioning system
	Globals.init_spatial_grid(screen_size)

	for i in range(num_reds):
		var red = RED_DOT_SCENE.instantiate()
		red.position = Vector2(
			randi() % int(screen_size.x),
			randi() % int(screen_size.y)
		)
		add_child(red)
		# Red dot will add itself to "reds" group in its _ready() method

	for i in range(num_greens):
		var green = GREEN_DOT_SCENE.instantiate()
		green.position = Vector2(
			randi() % int(screen_size.x),
			randi() % int(screen_size.y)
		)
		add_child(green)
		# (GreenDot script should already add itself to the "greens" group in _ready())

func _ready():
	randomize()  # Ensures randomness each time the scene runs
	spawn_agents()
