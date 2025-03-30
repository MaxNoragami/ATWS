extends Node2D

@export var entity_scene: PackedScene
@export var rigid_body_scene: PackedScene
@export var house_scene: PackedScene
@export var tank_scene: PackedScene
@export var remains_scene: PackedScene
@export var ufo_scene: PackedScene

var entities: Array[Entity] = []
var rigid_bodies: Array[RigidBody] = []
var houses: Array[House] = []
var tanks: Array[Tank] = []
var remains: Array = [] # Array of remains objects
var grid_size = Vector2i(Game.CELLS_AMOUNT.x, Game.CELLS_AMOUNT.y)
var occupied_positions: Dictionary = {}  # Stores all occupied grid positions
var pending_remains: Dictionary = {}  # Stores positions where destruction happened, waiting for tank to move off

var teams = {
	"Blue": Color(0.0, 0.0, 1.0),
	"Green": Color("1c5c2d"),
	"Red": Color(1.0, 0.0, 0.0),
	"Purple": Color(0.5, 0.0, 0.5)
}

var team_scores = {
	"Blue": 0,
	"Green": 0,
	"Red": 0,
	"Purple": 0
}

var current_team_index = 0
var team_names = ["Blue", "Green", "Red", "Purple"]

# Gender for new entities
var current_gender = Entity.Gender.MALE

# Placement mode variables
var placement_mode = false
var placement_preview: Node2D = null
enum PlacementType { ENTITY, RIGID_BODY, HOUSE, TANK }
var current_placement_type = PlacementType.ENTITY

# Debug mode
var debug_mode = false
var entities_to_remove: Array[Entity] = []
var tanks_to_remove: Array[Tank] = []
var reproduction_queue: Array = []  # Queue for entities to be born next turn
var destruction_queue: Array = []   # Queue for objects to be destroyed

func _ready() -> void:
	# Create a preview entity for placement mode
	create_placement_preview()
	# Initialize the occupied positions dictionary
	update_occupied_positions()

func create_placement_preview() -> void:
	# Remove any existing preview
	if placement_preview:
		placement_preview.queue_free()
	
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	var preview_color = Color(color.r, color.g, color.b, 0.5)  # 50% transparency
	
	if current_placement_type == PlacementType.ENTITY:
		placement_preview = entity_scene.instantiate() as Entity
		# For entity, we need to adapt to your entity's initialization method
		if placement_preview.has_method("initialize"):
			placement_preview.initialize(preview_color, team_name)
		else:
			var entity_preview = placement_preview as Entity
			entity_preview.entity_color = preview_color
			entity_preview.team = team_name
		
		# Set gender for preview
		var entity_preview = placement_preview as Entity
		entity_preview.gender = current_gender
		entity_preview.update_sprite_for_age_and_gender()
	elif current_placement_type == PlacementType.RIGID_BODY:
		placement_preview = rigid_body_scene.instantiate() as RigidBody
		placement_preview.initialize(preview_color, team_name)
	elif current_placement_type == PlacementType.HOUSE:
		placement_preview = house_scene.instantiate() as House
		placement_preview.initialize(preview_color, team_name)
	else:  # TANK
		placement_preview = tank_scene.instantiate() as Tank
		placement_preview.initialize(preview_color, team_name)
	
	placement_preview.visible = false  # Hide initially until placement mode is activated
	add_child(placement_preview)

func _process(delta: float) -> void:
	if placement_mode:
		update_placement_preview()
		
	# Process any pending entity removals
	if entities_to_remove.size() > 0:
		for entity in entities_to_remove:
			remove_entity(entity)
		entities_to_remove.clear()
		# Update occupied positions after removing entities
		update_occupied_positions()
		
		# Update debug visualization if needed
		if debug_mode:
			for entity in entities:
				if not entity.is_dead:
					entity.update_possible_moves(grid_size, occupied_positions)
					
	# Process any pending tank removals
	if tanks_to_remove.size() > 0:
		for tank in tanks_to_remove:
			remove_tank(tank)
		tanks_to_remove.clear()
		# Update occupied positions after removing tanks
		update_occupied_positions()

# Update the occupied positions dictionary
func update_occupied_positions() -> void:
	occupied_positions.clear()
	
	# Add entities to occupied positions
	for entity in entities:
		if not entity.is_dead:
			var pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
			occupied_positions[pos_string] = entity
	
	# Add rigid bodies to occupied positions
	for rigid_body in rigid_bodies:
		var pos_string = str(rigid_body.position_in_grid.x) + "," + str(rigid_body.position_in_grid.y)
		occupied_positions[pos_string] = rigid_body
		
	# Add houses to occupied positions
	for house in houses:
		var pos_string = str(house.position_in_grid.x) + "," + str(house.position_in_grid.y)
		occupied_positions[pos_string] = house
		
	# Add tanks to occupied positions
	for tank in tanks:
		if not tank.is_dead:
			var pos_string = str(tank.position_in_grid.x) + "," + str(tank.position_in_grid.y)
			occupied_positions[pos_string] = tank
		
	# Add remains to occupied positions
	for remain in remains:
		var pos_string = str(remain.position_in_grid.x) + "," + str(remain.position_in_grid.y)
		
		# Remains don't block movement, so only add them if position is not already occupied
		if not occupied_positions.has(pos_string):
			occupied_positions[pos_string] = remain

# Check if there are any available adjacent cells around a position
func has_available_adjacent_cell(pos: Vector2i) -> bool:
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
				
			var adjacent_pos = pos + Vector2i(x, y)
			
			# Check if position is within grid bounds
			if adjacent_pos.x >= 0 and adjacent_pos.x < grid_size.x and adjacent_pos.y >= 0 and adjacent_pos.y < grid_size.y:
				var pos_string = str(adjacent_pos.x) + "," + str(adjacent_pos.y)
				if not occupied_positions.has(pos_string):
					return true
	
	return false

# Check if a specific position is available (not occupied and within bounds)
func is_position_available(pos: Vector2i) -> bool:
	# Check if position is within grid bounds
	if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
		return false
		
	# Check if position is occupied by anything
	var pos_string = str(pos.x) + "," + str(pos.y)
	if occupied_positions.has(pos_string):
		return false
		
	# Extra check specifically for houses
	for house in houses:
		if pos == house.position_in_grid:
			return false
	
	return true

func update_placement_preview() -> void:
	# Get mouse position and convert to grid position
	var mouse_pos = get_global_mouse_position()
	var grid_pos = Vector2i(floor(mouse_pos.x / Game.CELL_SIZE.x), floor(mouse_pos.y / Game.CELL_SIZE.y))
	
	# Clamp to grid boundaries
	grid_pos.x = clamp(grid_pos.x, 0, grid_size.x - 1)
	grid_pos.y = clamp(grid_pos.y, 0, grid_size.y - 1)
	
	# Update preview position
	placement_preview.position_in_grid = grid_pos
	placement_preview.global_position = Vector2(grid_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
										   grid_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Update the team color of the preview
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	var preview_color = Color(color.r, color.g, color.b, 0.5)  # 50% transparency
	
	# Update sprite color
	if placement_preview.get_child_count() > 0 and placement_preview.get_child(0) is Sprite2D:
		placement_preview.get_child(0).modulate = preview_color
		
	# If house, update entrance positions
	if current_placement_type == PlacementType.HOUSE:
		var house_preview = placement_preview as House
		house_preview.update_entrance_positions()

func _input(event) -> void:
	if event.is_action_pressed("next_iteration"):
		process_iteration()
	
	if event.is_action_pressed("switch_team"):
		current_team_index = (current_team_index + 1) % team_names.size()
		print("Current team:", team_names[current_team_index])
		
		# Update preview if in placement mode
		if placement_mode:
			update_placement_preview()
	
	# Toggle gender for new entities
	if event.is_action_pressed("switch_gender"):
		if current_placement_type == PlacementType.ENTITY:
			if current_gender == Entity.Gender.MALE:
				current_gender = Entity.Gender.FEMALE
				print("Gender set to: Female")
			else:
				current_gender = Entity.Gender.MALE
				print("Gender set to: Male")
				
			# Update preview if in placement mode
			if placement_mode and placement_preview:
				var entity_preview = placement_preview as Entity
				entity_preview.gender = current_gender
				entity_preview.update_sprite_for_age_and_gender()
	
	# Toggle placement type
	if event.is_action_pressed("switch_entity") and placement_mode:
		if current_placement_type == PlacementType.ENTITY:
			current_placement_type = PlacementType.RIGID_BODY
			print("Placement type: Rigid Body")
		elif current_placement_type == PlacementType.RIGID_BODY:
			current_placement_type = PlacementType.HOUSE
			print("Placement type: House")
		elif current_placement_type == PlacementType.HOUSE:
			current_placement_type = PlacementType.TANK
			print("Placement type: Tank")
		else:
			current_placement_type = PlacementType.ENTITY
			print("Placement type: Entity")
		
		# Recreate the placement preview with the new type
		create_placement_preview()
		placement_preview.visible = true
	
	# Toggle placement mode
	if event.is_action_pressed("place_mode"):
		placement_mode = !placement_mode
		if placement_preview:
			placement_preview.visible = placement_mode
		print("Placement mode:", "ON" if placement_mode else "OFF")
	
	# Toggle debug mode
	if event.is_action_pressed("debug_mode"):
		debug_mode = !debug_mode
		print("Debug mode:", "ON" if debug_mode else "OFF")
		
		# Update all entities' debug visualization
		for entity in entities:
			if not entity.is_dead:
				entity.set_debug_visibility(debug_mode)
				if debug_mode:
					entity.update_possible_moves(grid_size, occupied_positions)
					
		# Update all tanks' debug visualization
		for tank in tanks:
			if not tank.is_dead:
				tank.set_debug_visibility(debug_mode)
				if debug_mode:
					tank.update_possible_moves(grid_size, occupied_positions)
	
	# Place entity or rigid body at current position
	if event.is_action_pressed("place_entity") and placement_mode:
		place_at_preview()

func process_iteration() -> void:
	# Update occupied positions for collision detection
	update_occupied_positions()
	
	# First, process any pending remains aging
	process_remains()
	
	# First check for reproduction opportunities
	check_for_reproduction()
	
	# Check for entities entering houses
	check_for_house_entries()
	
	# Process entities leaving houses
	process_house_exits()
	
	# Check for tank-to-tank combat
	check_for_tank_combat()
	
	# Process tanks movement and destruction
	for tank in tanks:
		if tank.is_dead:
			continue
			
		# Check for entities in tank's vision field and destroy them
		var vision_destroyed = tank.destroy_entities_in_vision(entities, rigid_bodies, houses, tanks, occupied_positions, grid_size)
		destruction_queue.append_array(vision_destroyed)
		
		# Store old position to check if tank has moved off a destruction site
		var old_position = tank.position_in_grid
		
		# Get current position and remove from occupied positions
		var old_pos_string = str(old_position.x) + "," + str(old_position.y)
		occupied_positions.erase(old_pos_string)
		
		# Move tank
		tank.move_randomly(grid_size, occupied_positions)
		
		# Check if tank drove over a destroyable object
		var destroyable = tank.check_for_destroyable_at_position(tank.position_in_grid, occupied_positions)
		if not destroyable.is_empty():
			destruction_queue.append(destroyable)
			# We immediately remove the object from occupied_positions so the tank can move there
			var destroy_pos_string = str(destroyable["position"].x) + "," + str(destroyable["position"].y)
			occupied_positions.erase(destroy_pos_string)
			
			# Store position and team of destroyed object for remains creation later
			var pos_string = str(tank.position_in_grid.x) + "," + str(tank.position_in_grid.y)
			pending_remains[pos_string] = {
				"position": tank.position_in_grid,
				"team": destroyable["team"]
			}
		
		# Check if tank moved off a destruction site
		if old_position != tank.position_in_grid:
			var old_pos_key = str(old_position.x) + "," + str(old_position.y)
			if pending_remains.has(old_pos_key):
				# Tank moved off a position where something was destroyed, create remains
				var remain_data = pending_remains[old_pos_key]
				create_remains(remain_data["position"], remain_data["team"])
				pending_remains.erase(old_pos_key)
		
		# Add new position to occupied positions
		var new_pos_string = str(tank.position_in_grid.x) + "," + str(tank.position_in_grid.y)
		occupied_positions[new_pos_string] = tank
	
	# Create a copy of the entities array to safely iterate
	var current_entities = entities.duplicate()
	
	# Process each entity's movement and aging
	for entity in current_entities:
		if not entity.is_dead:
			# Decrement house entry cooldown if it exists
			if entity.has_meta("house_entry_cooldown"):
				var cooldown = entity.get_meta("house_entry_cooldown")
				cooldown -= 1
				if cooldown <= 0:
					entity.remove_meta("house_entry_cooldown")
				else:
					entity.set_meta("house_entry_cooldown", cooldown)
					
			# Skip movement if entity just exited a house this turn
			if entity.has_meta("just_exited_house"):
				entity.remove_meta("just_exited_house")
				# Still age the entity
				entity.age_up()
				continue
				
			# Get current position and remove from occupied positions
			var old_pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
			occupied_positions.erase(old_pos_string)
			
			# Move entity
			entity.move_randomly(grid_size, occupied_positions)
			
			# Add new position to occupied positions
			var new_pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
			occupied_positions[new_pos_string] = entity
			
			# Age entity
			entity.age_up()
	
	# After all entities have moved, process any pending reproductions
	process_reproduction_queue()
	
	# Process destruction queue
	process_destruction_queue()
	
	# Check if any pending remains can be created
	process_pending_remains()
	
	# Update occupied positions again to ensure consistency
	update_occupied_positions()
	
	# Update debug visualization for all entities after all movements are complete
	if debug_mode:
		# First, make sure occupied_positions is completely up-to-date
		update_occupied_positions()
		
		# Then update the debug visualization for each entity
		for entity in entities:
			if not entity.is_dead:
				entity.update_possible_moves(grid_size, occupied_positions)
				
		# Update the debug visualization for each tank
		for tank in tanks:
			if not tank.is_dead:
				tank.update_possible_moves(grid_size, occupied_positions)

# Check for tank-to-tank combat
func check_for_tank_combat() -> void:
	for attacking_tank in tanks:
		if attacking_tank.is_dead:
			continue
			
		# Get the kill zone of this tank
		var kill_zone = attacking_tank.calculate_kill_zone()
		
		# Check if any other tank is in this kill zone
		for target_tank in tanks:
			if target_tank.is_dead or target_tank == attacking_tank or target_tank.team == attacking_tank.team:
				continue
				
			# Check if target tank is in the kill zone
			for kill_pos in kill_zone:
				if target_tank.position_in_grid == kill_pos:
					# Target tank is in kill zone, destroy it
					destruction_queue.append({
						"type": "tank",
						"object": target_tank,
						"position": target_tank.position_in_grid,
						"team": target_tank.team
					})
					print("Tank from team ", attacking_tank.team, " destroyed tank from team ", target_tank.team)
					break

# Triggered after each iteration is complete
func process_pending_remains() -> void:
	var positions_to_check = pending_remains.keys()
	var positions_to_remove = []
	
	# Check each pending remain position
	for pos_string in positions_to_check:
		# Parse position string
		var coords = pos_string.split(",")
		var grid_pos = Vector2i(int(coords[0]), int(coords[1]))
		
		# Check if position is now free (no tank or other entity)
		var is_free = true
		for tank in tanks:
			if not tank.is_dead and tank.position_in_grid == grid_pos:
				is_free = false
				break
		
		# If position is free, create remains and mark for removal from pending list
		if is_free:
			var remain_data = pending_remains[pos_string]
			create_remains(remain_data["position"], remain_data["team"])
			positions_to_remove.append(pos_string)
	
	# Remove processed positions
	for pos_string in positions_to_remove:
		pending_remains.erase(pos_string)

# Process remains objects - age them and remove if lifetime is over
func process_remains() -> void:
	var remains_to_remove = []
	
	for remain in remains:
		if remain.age():
			# This remains object has reached the end of its lifetime
			remains_to_remove.append(remain)
	
	# Remove expired remains
	for remain in remains_to_remove:
		# Remove from occupied positions
		var pos_string = str(remain.position_in_grid.x) + "," + str(remain.position_in_grid.y)
		if occupied_positions.has(pos_string) and occupied_positions[pos_string] == remain:
			occupied_positions.erase(pos_string)
		
		# Remove from array and free node
		var index = remains.find(remain)
		if index != -1:
			remains.remove_at(index)
		remain.queue_free()

# Create remains at a specific position
func create_remains(pos: Vector2i, team_name: String) -> void:
	var remain = remains_scene.instantiate() as Remains
	var color = teams[team_name]
	
	# Initialize the remains
	remain.initialize(color, team_name)
	remain.position_in_grid = pos
	remain.global_position = Vector2(pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
							pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	add_child(remain)
	remains.append(remain)
	
	# Do not mark remains as occupied yet - they will be when update_occupied_positions is called
	# This allows tanks to move through them

# Process the destruction queue
func process_destruction_queue() -> void:
	for item in destruction_queue:
		match item["type"]:
			"entity":
				var entity = item["object"] as Entity
				if not entity.is_dead:
					# Mark entity as dead
					entity.is_dead = true
					entity.emit_signal("entity_died", entity)
					print("Tank destroyed entity of team: ", entity.team)
					
			"rigid_body":
				var rigid_body = item["object"] as RigidBody
				# Remove rigid body
				var index = rigid_bodies.find(rigid_body)
				if index != -1:
					rigid_bodies.remove_at(index)
					rigid_body.queue_free()
					print("Tank destroyed rigid body of team: ", rigid_body.team)
				
			"house":
				var house = item["object"] as House
				# Kill all entities inside the house
				for entity in item["entities_inside"]:
					if not entity.is_dead:
						entity.is_dead = true
						entity.emit_signal("entity_died", entity)
				
				# Remove the house
				var index = houses.find(house)
				if index != -1:
					houses.remove_at(index)
					house.queue_free()
					print("Tank destroyed house of team: ", house.team, " with ", item["entities_inside"].size(), " entities inside")
			
			"tank":
				var tank = item["object"] as Tank
				if not tank.is_dead:
					# Mark tank as dead
					tank.is_dead = true
					
					# Create remains for the tank
					var pos_string = str(tank.position_in_grid.x) + "," + str(tank.position_in_grid.y)
					pending_remains[pos_string] = {
						"position": tank.position_in_grid,
						"team": tank.team
					}
					
					# Queue tank for removal
					tanks_to_remove.append(tank)
					print("Tank destroyed from team: ", tank.team)
	
	# Clear the destruction queue
	destruction_queue.clear()

# Function to remove a tank
func remove_tank(tank: Tank) -> void:
	# Remove from our tanks array
	var index = tanks.find(tank)
	if index != -1:
		tanks.remove_at(index)
	
	# Remove from occupied positions
	var pos_string = str(tank.position_in_grid.x) + "," + str(tank.position_in_grid.y)
	if occupied_positions.has(pos_string) and occupied_positions[pos_string] == tank:
		occupied_positions.erase(pos_string)
	
	# Free the tank node
	tank.queue_free()
	print("Tank removed")

# Check for entities entering houses
func check_for_house_entries() -> void:
	# Create a copy of the entities array to safely iterate
	var current_entities = entities.duplicate()
	
	for entity in current_entities:
		if entity.is_dead:
			continue
		
		# Check if entity is at a house entrance
		for house in houses:
			if house.can_entity_enter(entity, grid_size, occupied_positions):
				# Try to add entity to house
				if house.try_add_entity(entity):
					# Hide entity from grid
					entity.visible = false
					
					# Remove entity from occupied positions
					var pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
					occupied_positions.erase(pos_string)
					
					# Set entity position to house position (for bookkeeping)
					entity.position_in_grid = house.position_in_grid
					
					print("Entity entered house of team: ", house.team)
					break

# Process entities leaving houses
func process_house_exits() -> void:
	for house in houses:
		# Try to make an entity leave the house (random chance)
		if house.entities_inside.size() > 0 and randf() < 0.3:  # 30% chance per house per turn
			var result = house.try_remove_any_entity(grid_size, occupied_positions)
			var entity = result[0]
			var entrance_index = result[1]
			
			if entity != null and entrance_index >= 0:
				# Place entity at the entrance position
				var entrance_pos = house.entrance_positions[entrance_index]
				
				# Double-check that the entrance is actually free
				var pos_string = str(entrance_pos.x) + "," + str(entrance_pos.y)
				if occupied_positions.has(pos_string):
					# If somehow the entrance got occupied since we checked, put entity back in house
					house.entities_inside.push_front(entity)
					print("Exit blocked at last moment, entity stays in house")
					continue
				
				# Set entity position exactly at the entrance
				entity.position_in_grid = entrance_pos
				entity.visible = true
				
				# Update entity's global position
				entity.movement.update_position()
				
				# Mark position as occupied
				occupied_positions[pos_string] = entity
				
				# Flag this entity as having just exited a house (it will skip movement this turn)
				entity.set_meta("just_exited_house", true)
				
				# Flag this entity with a house entry cooldown (can't re-enter for 1 turn)
				entity.set_meta("house_entry_cooldown", 2)
				
				print("Entity exited house of team: ", house.team)

# Check for reproduction opportunities between entities
func check_for_reproduction() -> void:
	var adults_by_position = {}
	
	# First, collect all adult entities by their positions
	for entity in entities:
		if not entity.is_dead and entity.is_adult() and entity.visible:
			var pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
			adults_by_position[pos_string] = entity
	
	# Check each adult entity for potential reproduction
	for entity in entities:
		if entity.is_dead or not entity.is_adult() or entity.had_reproduction_this_turn or not entity.visible:
			continue
		
		# Check all 8 adjacent cells for compatible partners
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue  # Skip self
				
				var adjacent_pos = entity.position_in_grid + Vector2i(x, y)
				var pos_string = str(adjacent_pos.x) + "," + str(adjacent_pos.y)
				
				# Check if there's an adult entity at this position
				if adults_by_position.has(pos_string):
					var other_entity = adults_by_position[pos_string]
					
					# Check if they're compatible for reproduction
					if other_entity.team == entity.team and other_entity.gender != entity.gender and not other_entity.had_reproduction_this_turn:
						# Check if either entity has an available adjacent cell to move to
						if has_available_adjacent_cell(entity.position_in_grid) or has_available_adjacent_cell(other_entity.position_in_grid):
							# Try to reproduce
							if entity.try_reproduce(other_entity):
								# Schedule a child to be born
								reproduction_queue.append({
									"parent1": entity,
									"parent2": other_entity,
									"team": entity.team
								})
								break  # Only one reproduction per entity per turn
						else:
							# Both entities are surrounded, can't reproduce
							print("Cannot reproduce: no available cells for child")

# Process the reproduction queue and create new children
func process_reproduction_queue() -> void:
	for repro_data in reproduction_queue:
		var parent1 = repro_data["parent1"]
		var parent2 = repro_data["parent2"]
		
		# Collect all available cells around both parents
		var available_cells = []
		
		# Check parent1's adjacent cells
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue
					
				var adjacent_pos = parent1.position_in_grid + Vector2i(x, y)
				if is_position_available(adjacent_pos):
					available_cells.append(adjacent_pos)
		
		# Check parent2's adjacent cells
		for x in range(-1, 2):
			for y in range(-1, 2):
				if x == 0 and y == 0:
					continue
					
				var adjacent_pos = parent2.position_in_grid + Vector2i(x, y)
				if is_position_available(adjacent_pos):
					# Check if this position is already in our available cells list
					var is_duplicate = false
					for pos in available_cells:
						if pos == adjacent_pos:
							is_duplicate = true
							break
					
					if not is_duplicate:
						available_cells.append(adjacent_pos)
		
		# If no available cells found, skip this reproduction
		if available_cells.size() == 0:
			print("Skipping reproduction: no available cells for child")
			continue
		
		# Create a new entity at a random available adjacent cell
		var random_index = randi() % available_cells.size()
		var child_pos = available_cells[random_index]
		
		# Double check that the position is still available
		if not is_position_available(child_pos):
			print("Position became occupied, skipping reproduction")
			continue
		
		var child = entity_scene.instantiate() as Entity
		var color = teams[repro_data["team"]]
		
		# Initialize the child
		if child.has_method("initialize"):
			child.initialize(color, repro_data["team"])
		else:
			# Use whatever approach your entities are using
			child.entity_color = color
			child.team = repro_data["team"]
			
		child.position_in_grid = child_pos
		child.global_position = Vector2(child.position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
								child.position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
		
		# Randomly determine gender
		child.gender = Entity.Gender.MALE if randf() > 0.5 else Entity.Gender.FEMALE
		child.update_sprite_for_age_and_gender()
		
		# Set age to 0 (child)
		child.age = 0
		
		# Connect death signal
		child.connect("entity_died", on_entity_died)
		
		add_child(child)
		entities.append(child)
		
		# Mark this position as occupied
		var pos_string = str(child_pos.x) + "," + str(child_pos.y)
		occupied_positions[pos_string] = child
		
		print("New child born to team: ", repro_data["team"])
		
		# If debug mode is on, show possible moves
		if debug_mode:
			child.set_debug_visibility(true)
			child.update_possible_moves(grid_size, occupied_positions)
	
	# Clear the reproduction queue
	reproduction_queue.clear()

func on_entity_died(entity) -> void:
	# Add the entity to the removal queue
	if not entities_to_remove.has(entity):
		entities_to_remove.append(entity)
		
		# Remove the entity from occupied positions immediately to prevent overlap
		var pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
		if occupied_positions.has(pos_string) and occupied_positions[pos_string] == entity:
			occupied_positions.erase(pos_string)
		
		# If entity is inside a house, remove it from there too
		for house in houses:
			var index = house.entities_inside.find(entity)
			if index != -1:
				house.entities_inside.remove_at(index)

func remove_entity(entity) -> void:
	# Remove from our entities array
	var index = entities.find(entity)
	if index != -1:
		entities.remove_at(index)
	
	# Free the entity node
	entity.queue_free()
	print("Entity died at age: ", entity.age)

func place_at_preview() -> void:
	# Check if the position is already occupied
	var pos_string = str(placement_preview.position_in_grid.x) + "," + str(placement_preview.position_in_grid.y)
	if occupied_positions.has(pos_string):
		print("Cannot place: position already occupied")
		return
	
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	
	if current_placement_type == PlacementType.ENTITY:
		# Create a new entity at the preview position
		var entity = entity_scene.instantiate() as Entity
		
		# Initialize the entity
		if entity.has_method("initialize"):
			entity.initialize(color, team_name)
		else:
			# Use whatever approach your entities are using
			entity.entity_color = color
			entity.team = team_name
			
		entity.position_in_grid = placement_preview.position_in_grid
		entity.global_position = Vector2(entity.position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
									entity.position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
		
		# Set gender according to current selection
		entity.gender = current_gender
		entity.update_sprite_for_age_and_gender()
		
		# Connect death signal
		entity.connect("entity_died", on_entity_died)
		
		add_child(entity)
		entities.append(entity)
		
		# Mark this position as occupied immediately
		occupied_positions[pos_string] = entity
		
		# If debug mode is on, show possible moves
		if debug_mode:
			entity.set_debug_visibility(true)
			
			# Update debug visualization for all entities since we've changed the occupied positions
			for e in entities:
				if not e.is_dead:
					e.update_possible_moves(grid_size, occupied_positions)
			
	elif current_placement_type == PlacementType.RIGID_BODY:
		# Create a new rigid body at the preview position
		var rigid_body = rigid_body_scene.instantiate() as RigidBody
		rigid_body.initialize(color, team_name)
		rigid_body.position_in_grid = placement_preview.position_in_grid
		rigid_body.global_position = Vector2(rigid_body.position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
									rigid_body.position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
		
		add_child(rigid_body)
		rigid_bodies.append(rigid_body)
		
		# Mark this position as occupied immediately
		occupied_positions[pos_string] = rigid_body
		
	elif current_placement_type == PlacementType.HOUSE:
		# Create a new house at the preview position
		var house = house_scene.instantiate() as House
		house.initialize(color, team_name)
		house.position_in_grid = placement_preview.position_in_grid
		house.global_position = Vector2(house.position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
									house.position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
		
		# Update entrance positions
		house.update_entrance_positions()
		
		add_child(house)
		houses.append(house)
		
		# Mark this position as occupied immediately
		occupied_positions[pos_string] = house
		
	else:  # TANK
		# Create a new tank at the preview position
		var tank = tank_scene.instantiate() as Tank
		tank.initialize(color, team_name)
		tank.position_in_grid = placement_preview.position_in_grid
		tank.global_position = Vector2(tank.position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
									tank.position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
		
		add_child(tank)
		tanks.append(tank)
		
		# Mark this position as occupied immediately
		occupied_positions[pos_string] = tank
		
		# If debug mode is on, show vision area
		if debug_mode:
			tank.set_debug_visibility(true)
			tank.update_possible_moves(grid_size, occupied_positions)
