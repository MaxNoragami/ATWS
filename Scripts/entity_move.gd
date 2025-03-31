extends Node
class_name EntityMovement

# Reference to the parent entity
var entity: Entity
var possible_moves: Array[Vector2i] = []

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Get reference to parent entity
	entity = get_parent() as Entity
	if not entity:
		push_error("EntityMovement must be a child of an Entity node")

# Calculate all possible moves (8 directions, 1 square)
func calculate_possible_moves(grid_size: Vector2i, occupied_positions: Dictionary) -> Array[Vector2i]:
	possible_moves.clear()
	
	# Check all 8 directions (horizontal, vertical, diagonal)
	for x in range(-1, 2):
		for y in range(-1, 2):
			# Skip the current position (0,0)
			if x == 0 and y == 0:
				continue
				
			var new_pos = entity.position_in_grid + Vector2i(x, y)
			
			# Ensure new position stays within grid bounds
			if new_pos.x >= 0 and new_pos.x < grid_size.x and new_pos.y >= 0 and new_pos.y < grid_size.y:
				# Check if position is already occupied
				var pos_string = str(new_pos.x) + "," + str(new_pos.y)
				
				# Check specifically for water biomes, but allow sand biomes
				var is_water = false
				for key in occupied_positions.keys():
					if key == pos_string:
						var obj = occupied_positions[key]
						if obj is WaterBiome:  # Only check for water, not sand
							is_water = true
							break
				
				# Skip water positions
				if is_water:
					continue
				
				# Normal occupancy checking (allow sand which may be in occupied_positions)
				if not occupied_positions.has(pos_string):
					possible_moves.append(new_pos)
				# Special case: Check if position has a house and if entity can enter it
				elif occupied_positions.has(pos_string) and occupied_positions[pos_string] is House:
					var house = occupied_positions[pos_string] as House
					# If the house is from the same team and has space, consider it a possible move
					if house.team == entity.team and house.entities_inside.size() < house.max_capacity:
						# Check if this position is a valid entrance to the house
						for entrance_pos in house.entrance_positions:
							if new_pos == entrance_pos:
								# Check if entity has no house entry cooldown
								if not entity.has_meta("house_entry_cooldown"):
									possible_moves.append(new_pos)
								break
				# Special case: Allow sand biomes (they should slow movement, not prevent it)
				elif occupied_positions.has(pos_string) and occupied_positions[pos_string] is SandBiome:
					possible_moves.append(new_pos)
	
	return possible_moves

# Move entity randomly but only to valid adjacent cells
func move_randomly(grid_size: Vector2i, occupied_positions: Dictionary) -> void:
	# Calculate possible moves
	calculate_possible_moves(grid_size, occupied_positions)
	
	# If there are possible moves, choose one randomly
	if possible_moves.size() > 0:
		var random_index = randi() % possible_moves.size()
		var new_position = possible_moves[random_index]
		
		# Update entity's grid position
		entity.position_in_grid = new_position
		
		# Update entity's global position based on grid position
		update_position()
	# If no moves available, entity stays in place

# Function to update the entity's global position based on its grid position
func update_position() -> void:
	# Convert Vector2i to Vector2 for multiplication
	var grid_pos_float = Vector2(entity.position_in_grid.x, entity.position_in_grid.y)
	entity.global_position = grid_pos_float * Game.CELL_SIZE + Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2)

# Move to a specific grid position
func move_to_grid_position(grid_pos: Vector2i, grid_size: Vector2i, occupied_positions: Dictionary) -> bool:
	# Ensure position stays within grid bounds
	var new_position = grid_pos
	new_position.x = clamp(new_position.x, 0, grid_size.x - 1)
	new_position.y = clamp(new_position.y, 0, grid_size.y - 1)
	
	# Check if position is already occupied
	var pos_string = str(new_position.x) + "," + str(new_position.y)
	if occupied_positions.has(pos_string) and occupied_positions[pos_string] != entity:
		# Special case: Check if position has a house and if entity can enter it
		if occupied_positions[pos_string] is House:
			var house = occupied_positions[pos_string] as House
			# If the house is from the same team and has space, allow moving to it
			if house.team == entity.team and house.entities_inside.size() < house.max_capacity:
				# Check if this position is a valid entrance to the house
				for entrance_pos in house.entrance_positions:
					if new_position == entrance_pos:
						# Update entity's grid position
						entity.position_in_grid = new_position
						# Update entity's global position
						update_position()
						return true
		
		return false
	
	# Update entity's grid position
	entity.position_in_grid = new_position
	
	# Update entity's global position
	update_position()
	return true