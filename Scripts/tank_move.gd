extends Node
class_name TankMovement

# Reference to the parent tank
var tank: Tank
var possible_moves: Array[Vector2i] = []

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Get reference to parent tank
	tank = get_parent() as Tank
	if not tank:
		push_error("TankMovement must be a child of a Tank node")


func calculate_possible_moves(grid_size: Vector2i, occupied_positions: Dictionary) -> Array[Vector2i]:
	possible_moves.clear()
	
	# Check 4 directions (horizontal and vertical only, no diagonals)
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0)   # Left
	]
	
	for dir in directions:
		var new_pos = tank.position_in_grid + dir
		
		# Ensure new position stays within grid bounds
		if new_pos.x >= 0 and new_pos.x < grid_size.x and new_pos.y >= 0 and new_pos.y < grid_size.y:
			# Check if position is already occupied
			var pos_string = str(new_pos.x) + "," + str(new_pos.y)
			
			# Skip water biomes - tanks cannot move into or destroy water
			var is_water = false
			if occupied_positions.has(pos_string):
				var obj = occupied_positions[pos_string]
				if obj is WaterBiome:
					is_water = true
			
			if is_water:
				continue
				
			if not occupied_positions.has(pos_string):
				possible_moves.append(new_pos)
			# Special case: Remains don't block tank movement
			elif occupied_positions.has(pos_string) and occupied_positions[pos_string] is Remains:
				possible_moves.append(new_pos)
			# Special case: Enemy structures can be destroyed, so tank can move there
			elif occupied_positions.has(pos_string):
				var object = occupied_positions[pos_string]
				if object.has_method("initialize") and object.team != tank.team:
					if object is RigidBody or object is House:
						possible_moves.append(new_pos)
	
	return possible_moves

# Move tank randomly but only to valid adjacent cells
func move_randomly(grid_size: Vector2i, occupied_positions: Dictionary) -> void:
	# Calculate possible moves
	calculate_possible_moves(grid_size, occupied_positions)
	
	# If there are possible moves, choose one randomly
	if possible_moves.size() > 0:
		var random_index = randi() % possible_moves.size()
		var new_position = possible_moves[random_index]
		
		# Check if there's a destroyable object at the new position
		var destroyable = tank.check_for_destroyable_at_position(new_position, occupied_positions)
		
		# Even if there's something to destroy, the tank can still move there
		# The game_loop will handle the actual destruction
		
		# Determine new facing direction based on movement
		var dir = new_position - tank.position_in_grid
		tank.facing_direction = dir
		
		# Update tank's grid position
		tank.position_in_grid = new_position
		
		# Update tank's global position based on grid position
		update_position()
	# If no moves available, tank stays in place but may still change direction
	else:
		# Randomly change direction without moving
		var directions = [
			Vector2i(0, -1),  # Up
			Vector2i(1, 0),   # Right
			Vector2i(0, 1),   # Down
			Vector2i(-1, 0)   # Left
		]
		var random_index = randi() % directions.size()
		tank.facing_direction = directions[random_index]

# Function to update the tank's global position based on its grid position
func update_position() -> void:
	# Convert Vector2i to Vector2 for multiplication
	var grid_pos_float = Vector2(tank.position_in_grid.x, tank.position_in_grid.y)
	tank.global_position = grid_pos_float * Game.CELL_SIZE + Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2)
