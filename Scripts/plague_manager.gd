extends Node

class_name PlagueManager

var plague_cells: Dictionary = {}  # Stores plague cells by position string
var plague_to_remove: Array[Plague] = []
var grid_size: Vector2i
var game_node  # Reference to game_loop

# Initialize the manager
func initialize(game_reference, grid_dimensions: Vector2i) -> void:
	game_node = game_reference
	grid_size = grid_dimensions

# Add this at the end of your plague_manager.gd file
func clear_all_plague_cells() -> void:
	# Remove all plague cells from the scene
	for pos_string in plague_cells.keys():
		if plague_cells[pos_string] != null:
			plague_cells[pos_string].queue_free()
	
	# Clear the plague cells dictionary
	plague_cells.clear()
	
	# Clear the removal queue
	plague_to_remove.clear()

# Add a new plague cell at the specified position
func add_plague_cell(pos: Vector2i, plague_scene: PackedScene) -> void:
	var pos_string = str(pos.x) + "," + str(pos.y)
	
	# Skip if position already has plague
	if plague_cells.has(pos_string):
		return
	
	# Create a new plague cell
	var plague = plague_scene.instantiate() as Plague
	
	# Initialize the plague with position
	plague.initialize(pos)
	
	# Connect plague ended signal
	plague.connect("plague_ended", on_plague_ended)
	
	# Add to scene
	game_node.add_child(plague)
	
	# Add to dictionary
	plague_cells[pos_string] = plague
	
	# Mark as occupied in game_node
	game_node.occupied_positions[pos_string] = plague
	
	print("Plague cell added at: ", pos)

# Remove a plague cell
func remove_plague_cell(plague: Plague) -> void:
	var pos_string = str(plague.position_in_grid.x) + "," + str(plague.position_in_grid.y)
	
	# Remove from dictionary
	if plague_cells.has(pos_string):
		plague_cells.erase(pos_string)
	
	# Remove from occupied positions
	if game_node.occupied_positions.has(pos_string) and game_node.occupied_positions[pos_string] == plague:
		game_node.occupied_positions.erase(pos_string)
	
	# Free the node
	plague.queue_free()
	
	print("Plague cell removed from: ", plague.position_in_grid)

# Handle plague cell reaching end of lifetime
func on_plague_ended(plague: Plague) -> void:
	# Add to removal queue
	if not plague_to_remove.has(plague):
		plague_to_remove.append(plague)

# Spawn initial plague cells after bomb explosion
func spawn_initial_plague(explosion_positions: Array[Vector2i], plague_count: int, plague_scene: PackedScene) -> void:
	# Shuffle explosion positions to randomize plague spawning
	var shuffled_positions = explosion_positions.duplicate()
	shuffled_positions.shuffle()
	
	# Spawn up to plague_count cells, but no more than available positions
	var cells_to_spawn = min(plague_count, shuffled_positions.size())
	
	for i in range(cells_to_spawn):
		var pos = shuffled_positions[i]
		
		# Skip positions with a jet - plague can't spawn on jets
		var pos_string = str(pos.x) + "," + str(pos.y)
		if game_node.occupied_positions.has(pos_string):
			var object = game_node.occupied_positions[pos_string]
			if object is FighterJet:
				continue
		
		add_plague_cell(pos, plague_scene)

# Process the plague cells according to Conway's Game of Life
func process_plague_turn(plague_scene: PackedScene) -> void:
	# First, process each plague cell's lifetime
	for pos_string in plague_cells.keys():
		var plague = plague_cells[pos_string]
		if plague.process_turn():
			continue  # Cell will be removed by signal handler
	
	# Calculate new plague state based on Conway's Game of Life rules
	var cells_to_add: Array[Vector2i] = []
	var cells_to_remove: Array[Vector2i] = []
	
	# First, check for cells to remove (fewer than 2 or more than 3 neighbors)
	for pos_string in plague_cells.keys():
		var coords = pos_string.split(",")
		var pos = Vector2i(int(coords[0]), int(coords[1]))
		
		var live_neighbors = count_live_neighbors(pos)
		
		# Rules 1 & 3: Any live cell with fewer than 2 or more than 3 live neighbors dies
		if live_neighbors < 2 or live_neighbors > 3:
			cells_to_remove.append(pos)
	
	# Then, check for cells to add (empty cell with exactly 3 neighbors)
	# Gather all potential empty cells adjacent to plague cells
	var potential_empty_cells = {}
	
	for pos_string in plague_cells.keys():
		var coords = pos_string.split(",")
		var pos = Vector2i(int(coords[0]), int(coords[1]))
		
		# Check all 8 neighbors
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue  # Skip the cell itself
				
				var neighbor_pos = pos + Vector2i(x, y)
				
				# Skip if out of bounds
				if neighbor_pos.x < 0 or neighbor_pos.x >= grid_size.x or neighbor_pos.y < 0 or neighbor_pos.y >= grid_size.y:
					continue
					
				var neighbor_pos_string = str(neighbor_pos.x) + "," + str(neighbor_pos.y)
				
				# If not already a plague cell, add to potential empty cells
				if not plague_cells.has(neighbor_pos_string):
					potential_empty_cells[neighbor_pos_string] = neighbor_pos
	
	# Check each potential empty cell
	for pos_string in potential_empty_cells.keys():
		var pos = potential_empty_cells[pos_string]
		
		var live_neighbors = count_live_neighbors(pos)
		
		# Rule 4: Any dead cell with exactly 3 live neighbors becomes a live cell
		if live_neighbors == 3:
			# Skip positions with a jet - plague can't affect jets
			if is_jet_at_position(pos):
				continue
				
			cells_to_add.append(pos)
	
	# Apply changes: destroy everything that plague will touch
	for pos in cells_to_add:
		destroy_at_position(pos)
	
	# Apply changes: remove cells that die
	for pos in cells_to_remove:
		var pos_string = str(pos.x) + "," + str(pos.y)
		if plague_cells.has(pos_string):
			remove_plague_cell(plague_cells[pos_string])
	
	# Apply changes: add new cells
	for pos in cells_to_add:
		add_plague_cell(pos, plague_scene)
	
	# Clean up any plague cells that have reached their lifetime
	for plague in plague_to_remove:
		remove_plague_cell(plague)
	plague_to_remove.clear()

# Count live plague cell neighbors at a position
func count_live_neighbors(pos: Vector2i) -> int:
	var count = 0
	
	# Check all 8 neighbors
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue  # Skip the cell itself
			
			var neighbor_pos = pos + Vector2i(x, y)
			
			# Skip if out of bounds
			if neighbor_pos.x < 0 or neighbor_pos.x >= grid_size.x or neighbor_pos.y < 0 or neighbor_pos.y >= grid_size.y:
				continue
				
			var neighbor_pos_string = str(neighbor_pos.x) + "," + str(neighbor_pos.y)
			
			# Increment count if neighbor has plague
			if plague_cells.has(neighbor_pos_string):
				count += 1
	
	return count

# Check if there's a jet at the position
func is_jet_at_position(pos: Vector2i) -> bool:
	var pos_string = str(pos.x) + "," + str(pos.y)
	
	if game_node.occupied_positions.has(pos_string):
		return game_node.occupied_positions[pos_string] is FighterJet
		
	return false

# Destroy any object at the position (the plague is destroying it)
func destroy_at_position(pos: Vector2i) -> void:
	var pos_string = str(pos.x) + "," + str(pos.y)
	
	if game_node.occupied_positions.has(pos_string):
		var object = game_node.occupied_positions[pos_string]
		
		# Skip jets - plague doesn't affect jets
		if object is FighterJet:
			return
			
		# Handle different types of objects
		if object is Entity and object.visible:
			# Mark entity as dead
			object.is_dead = true
			object.emit_signal("entity_died", object)
			print("Plague destroyed entity at: ", pos)
			
		elif object is RigidBody:
			# Remove rigid body
			var index = game_node.rigid_bodies.find(object)
			if index != -1:
				game_node.rigid_bodies.remove_at(index)
				object.queue_free()
				print("Plague destroyed rigid body at: ", pos)
			
		elif object is House:
			# Kill all entities inside the house
			for entity in object.entities_inside:
				if not entity.is_dead:
					entity.is_dead = true
					entity.emit_signal("entity_died", entity)
			
			# Remove the house
			var index = game_node.houses.find(object)
			if index != -1:
				game_node.houses.remove_at(index)
				object.queue_free()
				print("Plague destroyed house at: ", pos)
		
		elif object is Tank and not object.is_dead:
			# Mark tank as dead
			object.is_dead = true
			
			# Add to removal queue
			game_node.tanks_to_remove.append(object)
			print("Plague destroyed tank at: ", pos)
			
		elif object is WaterBiome or object is SandBiome:
			# Remove biome
			var biome_pos_string = str(pos.x) + "," + str(pos.y)
			if game_node.biomes.has(biome_pos_string):
				var biome = game_node.biomes[biome_pos_string]
				game_node.biomes.erase(biome_pos_string)
				biome.queue_free()
				print("Plague destroyed biome at: ", pos)
		
		# Remove from occupied positions
		game_node.occupied_positions.erase(pos_string)
