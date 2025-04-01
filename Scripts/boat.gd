extends Node2D

class_name Boat

@export var sprite: Texture2D
var entity_color: Color = Color(1.0, 1.0, 1.0)  # Default color (white)
var team: String = "None"
var position_in_grid: Vector2i
var facing_direction: Vector2i = Vector2i(0, -1)  # Default facing up
var is_dead: bool = false

# Atlas coordinates for different directions
var sprite_atlas = {
	"up": Vector2i(9, 19),     # (0, -1) Up
	"down": Vector2i(10, 19),   # (0, 1) Down
	"right": Vector2i(11, 19), # (1, 0) Right
	"left": Vector2i(11, 19)   # (-1, 0) Left (same as right but flipped)
}

# Movement variables
var movement_cooldown: int = 0
var movement_cooldown_max: int = 3  # Move every X turns
var debug_visualizer: BoatDebugVisualizer

func _init(color: Color = Color(1.0, 1.0, 1.0), team_name: String = "None") -> void:
	entity_color = color
	team = team_name

func _ready() -> void:
	z_index = 5  # Above water but below some other entities
	
	# Create sprite
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	
	# Apply color tint
	sprite_node.modulate = entity_color
	
	add_child(sprite_node)
	
	# Set initial sprite based on direction
	update_sprite_for_direction()
	
	# Add debug visualizer
	debug_visualizer = BoatDebugVisualizer.new(self)
	add_child(debug_visualizer)

# Initialize with custom parameters
func initialize(color: Color, team_name: String) -> void:
	entity_color = color
	team = team_name
	
	# Update the sprite if it already exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = entity_color

# Update possible moves and debug visualization
func update_possible_moves(grid_size: Vector2i, occupied_positions: Dictionary, biomes: Dictionary) -> void:
	var moves = calculate_possible_moves(grid_size, occupied_positions, biomes)
	debug_visualizer.show_possible_moves(moves)

# Calculate all possible moves (4 directions, 1 square, water only)
func calculate_possible_moves(grid_size: Vector2i, occupied_positions: Dictionary, biomes: Dictionary) -> Array[Vector2i]:
	var possible_moves: Array[Vector2i] = []
	
	# Check 4 directions (horizontal and vertical only, no diagonals)
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0)   # Left
	]
	
	for dir in directions:
		var new_pos = position_in_grid + dir
		
		# Ensure new position stays within grid bounds
		if new_pos.x >= 0 and new_pos.x < grid_size.x and new_pos.y >= 0 and new_pos.y < grid_size.y:
			var pos_string = str(new_pos.x) + "," + str(new_pos.y)
			
			# Check if position is WATER biome (boat can only move on water)
			var is_water = false
			if biomes.has(pos_string) and biomes[pos_string] is WaterBiome:
				is_water = true
			
			# Boat must move ONLY on water
			if not is_water:
				continue
				
			# Check if position is already occupied by another entity
			if not occupied_positions.has(pos_string):
				possible_moves.append(new_pos)
	
	return possible_moves

# Move boat randomly but only on water
func move_randomly(grid_size: Vector2i, occupied_positions: Dictionary, biomes: Dictionary) -> void:
	# Check if it's time to move
	if movement_cooldown > 0:
		movement_cooldown -= 1
		return
		
	# Calculate possible moves
	var moves = calculate_possible_moves(grid_size, occupied_positions, biomes)
	
	# If there are possible moves, choose one randomly
	if moves.size() > 0:
		var random_index = randi() % moves.size()
		var new_position = moves[random_index]
		
		# Update facing direction based on movement
		var dir = new_position - position_in_grid
		facing_direction = dir
		
		# Update position
		position_in_grid = new_position
		
		# Update global position based on grid position
		update_position()
		
		# Update sprite direction
		update_sprite_for_direction()
	else:
		# No moves available, just randomly change direction
		var directions = [
			Vector2i(0, -1),  # Up
			Vector2i(1, 0),   # Right
			Vector2i(0, 1),   # Down
			Vector2i(-1, 0)   # Left
		]
		var random_index = randi() % directions.size()
		facing_direction = directions[random_index]
		update_sprite_for_direction()
	
	# Reset movement cooldown
	movement_cooldown = movement_cooldown_max

# Update the boat's global position based on its grid position
func update_position() -> void:
	# Convert Vector2i to Vector2 for multiplication
	var grid_pos_float = Vector2(position_in_grid.x, position_in_grid.y)
	global_position = grid_pos_float * Game.CELL_SIZE + Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2)

# Update sprite based on direction
func update_sprite_for_direction() -> void:
	var atlas_coords: Vector2i
	
	# Set default value in case no match is found
	atlas_coords = sprite_atlas["up"]  # Default to "up" direction
	
	# Convert Vector2i direction to string key
	if facing_direction == Vector2i(0, -1):
		atlas_coords = sprite_atlas["up"]
	elif facing_direction == Vector2i(0, 1):
		atlas_coords = sprite_atlas["down"]
	elif facing_direction == Vector2i(1, 0):
		atlas_coords = sprite_atlas["right"]
	elif facing_direction == Vector2i(-1, 0):
		atlas_coords = sprite_atlas["left"]
	
	# Make sure we have valid sprite node before trying to update it
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		sprite_node.region_rect = Rect2(atlas_coords.x * 16, atlas_coords.y * 16, 16, 16)
		
		# Handle flipping for left direction
		sprite_node.flip_h = (facing_direction == Vector2i(-1, 0))  # Flip if facing left

# Helper function to set opacity (useful for preview)
func set_opacity(opacity: float) -> void:
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		var current_color = sprite_node.modulate
		sprite_node.modulate = Color(current_color.r, current_color.g, current_color.b, opacity)

# Toggle debug visualization
func set_debug_visibility(visible: bool) -> void:
	debug_visualizer.set_visibility(visible)
	
	
# Add this method to the Boat class in boat.gd

# Helper method to set the grid position safely
func set_position_in_grid(pos: Vector2i) -> void:
	position_in_grid = pos
	# Update global position based on grid position
	var grid_pos_float = Vector2(position_in_grid.x, position_in_grid.y)
	global_position = grid_pos_float * Game.CELL_SIZE + Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2)
