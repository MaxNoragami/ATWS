extends Node2D

const FighterJet = preload("res://Scripts/jet.gd")
const Bomb = preload("res://Scripts/bomb.gd")

@export var entity_scene: PackedScene
@export var rigid_body_scene: PackedScene
@export var house_scene: PackedScene
@export var tank_scene: PackedScene
@export var remains_scene: PackedScene
@export var ufo_scene: PackedScene
@export var sand_scene: PackedScene  # Add sand biome scene
@export var water_scene: PackedScene
@export var jet_scene: PackedScene
@export var bomb_scene: PackedScene
@export var plague_scene: PackedScene



var entities: Array[Entity] = []
var rigid_bodies: Array[RigidBody] = []
var houses: Array[House] = []
var tanks: Array[Tank] = []
var remains: Array = [] # Array of remains objects
var grid_size = Vector2i(Game.CELLS_AMOUNT.x, Game.CELLS_AMOUNT.y)
var occupied_positions: Dictionary = {}  # Stores all occupied grid positions
var pending_remains: Dictionary = {}  # Stores positions where destruction happened, waiting for tank to move off
var ufos: Array[UFO] = []
var ufos_to_remove: Array[UFO] = []
var biomes: Dictionary = {}  # Stores biome tiles by position string
# Fighter jet variables
var jets: Array[FighterJet] = []
var bombs: Array[Bomb] = []
var bombs_to_remove: Array[Bomb] = []
var jets_to_remove: Array[FighterJet] = []
var plague_manager: PlagueManager
var plagues: Array[Plague] = []

var teams = {
	"Blue": Color(0.0, 0.0, 1.0),
	"Green": Color("1c5c2d"),
	"Red": Color(1.0, 0.0, 0.0),
	"Purple": Color(0.5, 0.0, 0.5),
	"None": Color(0.5, 0.5, 0.5)
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
enum PlacementType { ENTITY, RIGID_BODY, HOUSE, TANK, SAND_BIOME, WATER_BIOME, BOMB }
var current_placement_type = PlacementType.ENTITY

# Debug mode
var debug_mode = false
var entities_to_remove: Array[Entity] = []
var tanks_to_remove: Array[Tank] = []
var reproduction_queue: Array = []  # Queue for entities to be born next turn
var destruction_queue: Array = []   # Queue for objects to be destroyed

# UI state variables
var game_active = false
var config_window_visible = false

# Auto evolution variables
var auto_evolution_active: bool = false
var evolution_timer: Timer
@export var auto_evolution_interval: float = 1.0  # Default: 1 second interval

func _ready() -> void:
	# Set up the evolution timer
	evolution_timer = Timer.new()
	evolution_timer.one_shot = false
	evolution_timer.wait_time = auto_evolution_interval
	evolution_timer.connect("timeout", _on_evolution_timer_timeout)
	add_child(evolution_timer)

	
	plague_manager = PlagueManager.new()
	plague_manager.initialize(self, Vector2i(Game.CELLS_AMOUNT.x, Game.CELLS_AMOUNT.y))
	add_child(plague_manager)	
	# Create a preview entity for placement mode
	create_placement_preview()
	# Initialize the occupied positions dictionary
	update_occupied_positions()
	
	# Connect UI signals
	var menu = $CanvasLayer/Menu
	var tooltip = $CanvasLayer/Tooltip
	var info = $CanvasLayer/Info
	var credits = $CanvasLayer/Credits
	
	# Set references between UI elements
	if menu and credits:
		menu.credits_screen = credits

	menu.connect("play_pressed", start_game)
	
	if credits:
		credits.visible = false
		
	# Start with menu visible
	menu.visible = true
	tooltip.visible = false
	info.visible = false
	game_active = false

# Timer timeout handler for auto evolution
func _on_evolution_timer_timeout() -> void:
	if game_active and auto_evolution_active:
		process_iteration()

# Toggle auto evolution on/off
func toggle_auto_evolution() -> void:
	auto_evolution_active = !auto_evolution_active
	
	if auto_evolution_active:
		# Start the timer
		evolution_timer.wait_time = auto_evolution_interval
		evolution_timer.start()
		print("Auto evolution started - interval: ", auto_evolution_interval, "s")
	else:
		# Stop the timer
		evolution_timer.stop()
		print("Auto evolution stopped")

func start_game():
	game_active = true
	$CanvasLayer/Menu.visible = false
	$CanvasLayer/Tooltip.visible = true
	$CanvasLayer/Info.visible = false

func reset_game():
	# Clear all entities
	print("DEBUG: Clearing " + str(entities.size()) + " entities")
	for entity in entities:
		if is_instance_valid(entity) and !entity.is_queued_for_deletion():
			entity.visible = false  # Immediately hide it
			entity.queue_free()
	entities.clear()
	entities_to_remove.clear()

	if auto_evolution_active:
		toggle_auto_evolution()
	
	# Clear all rigid bodies
	for rigid_body in rigid_bodies:
		if is_instance_valid(rigid_body) and !rigid_body.is_queued_for_deletion():
			rigid_body.visible = false
			rigid_body.queue_free()
	rigid_bodies.clear()
	
	# Clear all houses
	for house in houses:
		if is_instance_valid(house) and !house.is_queued_for_deletion():
			house.visible = false
			house.queue_free()
	houses.clear()
	
	# Clear all tanks
	print("DEBUG: Clearing " + str(tanks.size()) + " tanks")
	for tank in tanks:
		if is_instance_valid(tank) and !tank.is_queued_for_deletion():
			tank.visible = false
			tank.queue_free()
	tanks.clear()
	tanks_to_remove.clear()
	
	# Clear all remains
	for remain in remains:
		if is_instance_valid(remain) and !remain.is_queued_for_deletion():
			remain.visible = false
			remain.queue_free()
	remains.clear()
	
	# Clear all UFOs
	for ufo in ufos:
		if is_instance_valid(ufo) and !ufo.is_queued_for_deletion():
			ufo.visible = false
			ufo.queue_free()
	ufos.clear()
	ufos_to_remove.clear()
   
	# Clear all jets
	print("DEBUG: Clearing " + str(jets.size()) + " jets")
	for jet in jets:
		if is_instance_valid(jet) and !jet.is_queued_for_deletion():
			jet.visible = false
			jet.queue_free()
	jets.clear()
	jets_to_remove.clear()
	
	# Clear all bombs
	for bomb in bombs:
		if is_instance_valid(bomb) and !bomb.is_queued_for_deletion():
			bomb.visible = false
			bomb.queue_free()
	bombs.clear()
	bombs_to_remove.clear()
	
	# Clear all biomes
	for pos_string in biomes.keys():
		if biomes[pos_string] != null and is_instance_valid(biomes[pos_string]) and !biomes[pos_string].is_queued_for_deletion():
			biomes[pos_string].visible = false
			biomes[pos_string].queue_free()
	biomes.clear()
	
	# Clear plague cells
	plague_manager.clear_all_plague_cells()
	
	entities.resize(0)
	tanks.resize(0)
	jets.resize(0)
	bombs.resize(0)
	houses.resize(0)
	rigid_bodies.resize(0)
	remains.resize(0)
	ufos.resize(0)
	entities_to_remove.resize(0)
	tanks_to_remove.resize(0)
	bombs_to_remove.resize(0)
	jets_to_remove.resize(0)
	ufos_to_remove.resize(0)

	# Reset UI state
	game_active = false
	$CanvasLayer/Menu.visible = true
	$CanvasLayer/Tooltip.visible = false
	$CanvasLayer/Info.visible = false
	
	# Reset occupied positions
	occupied_positions.clear()
	pending_remains.clear()
	
	# Reset placement mode
	placement_mode = false
	if placement_preview:
		placement_preview.visible = false
	
	await get_tree().process_frame
	
func create_placement_preview() -> void:
	# Remove any existing preview
	if placement_preview:
		placement_preview.queue_free()
	
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	var preview_color = Color(color.r, color.g, color.b, 0.5)  # 50% transparency
	
	if current_placement_type == PlacementType.ENTITY:
		placement_preview = entity_scene.instantiate() as Entity
		
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

		# Mark as preview to prevent visual effects
		entity_preview.is_preview = true

	elif current_placement_type == PlacementType.RIGID_BODY:
		placement_preview = rigid_body_scene.instantiate() as RigidBody
		placement_preview.initialize(preview_color, team_name)
	elif current_placement_type == PlacementType.HOUSE:
		placement_preview = house_scene.instantiate() as House
		placement_preview.initialize(preview_color, team_name)
	elif current_placement_type == PlacementType.TANK:
		placement_preview = tank_scene.instantiate() as Tank
		placement_preview.initialize(preview_color, team_name)
	elif current_placement_type == PlacementType.SAND_BIOME:
		placement_preview = sand_scene.instantiate() as SandBiome
		# Sand biome doesn't need team color, but we'll create a generic preview
		placement_preview.set_opacity(0.5)  # 50% transparency for preview
	elif current_placement_type == PlacementType.WATER_BIOME:
		placement_preview = water_scene.instantiate() as WaterBiome
		# Water biome doesn't need team color, but we'll create a generic preview
		placement_preview.set_opacity(0.5)
	
	elif current_placement_type == PlacementType.BOMB:
		placement_preview = bomb_scene.instantiate() as Bomb
		placement_preview.initialize(Vector2i(0, 0))  # Temporary position
		# Make sure the child exists before trying to access its modulate property
		if placement_preview.get_child_count() > 0 and placement_preview.get_child(0) is Sprite2D:
			placement_preview.get_child(0).modulate.a = 0.5  # 50% transparency for preview
		# Alternative way to set opacity if the bomb has a set_opacity method
		elif placement_preview.has_method("set_opacity"):
			placement_preview.set_opacity(0.5)
		
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
	
	# Add water biomes to occupied positions (but not sand - keep original behavior)
	for pos_string in biomes.keys():
		# Only add water biomes to occupied positions
		# Sand biomes should not block movement (they just slow it down)
		if biomes[pos_string] is WaterBiome:
			occupied_positions[pos_string] = biomes[pos_string]
	
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
	
	# Add UFOs to occupied positions
	for ufo in ufos:
		var pos_string = str(ufo.position_in_grid.x) + "," + str(ufo.position_in_grid.y)
		occupied_positions[pos_string] = ufo
		
	# Add remains to occupied positions
	for remain in remains:
		var pos_string = str(remain.position_in_grid.x) + "," + str(remain.position_in_grid.y)
		
		# Remains don't block movement, so only add them if position is not already occupied
		if not occupied_positions.has(pos_string):
			occupied_positions[pos_string] = remain
			
	# Add jets to occupied positions (optional - jets move fast and don't need to block)
	for jet in jets:
		var pos_string = str(jet.position_in_grid.x) + "," + str(jet.position_in_grid.y)
		# Only mark as occupied if not already occupied
		if not occupied_positions.has(pos_string):
			occupied_positions[pos_string] = jet
			
	# Add bombs to occupied positions (optional - bombs can overlap with other objects)
	for bomb in bombs:
		var pos_string = str(bomb.position_in_grid.x) + "," + str(bomb.position_in_grid.y)
		# Only mark as occupied if not already occupied
		if not occupied_positions.has(pos_string):
			occupied_positions[pos_string] = bomb
	# Add plague cells to occupied positions - add this at the end of the function
	for pos_string in plague_manager.plague_cells.keys():
			occupied_positions[pos_string] = plague_manager.plague_cells[pos_string]
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
	# Don't update preview if game is not active
	if not game_active:
		return

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
	
	# Update the team color of the preview (not applicable to biomes)
	if current_placement_type != PlacementType.SAND_BIOME && current_placement_type != PlacementType.WATER_BIOME:
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
	# First check for escape key to exit the game
	if event.is_action_pressed("exit") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo):
		if $CanvasLayer/Config.visible:
			# If config is visible, apply settings and hide it
			$CanvasLayer/Config.apply_configuration()
			$CanvasLayer/Config.visible = false
			config_window_visible = false
		elif $CanvasLayer/Info.visible:
			# If info is visible, just hide it
			$CanvasLayer/Info.visible = false
		elif $CanvasLayer/Credits.visible:
			# If credits are visible, hide them and show menu
			$CanvasLayer/Credits.visible = false
			$CanvasLayer/Menu.visible = true
		elif game_active:
			# If game is active, reset everything and go back to menu
			reset_game()
		return
	
	# Handle info panel toggling (only when game is active)
	if game_active and (event.is_action_pressed("info") or (event is InputEventKey and event.keycode == KEY_I and event.pressed and not event.echo)):
		$CanvasLayer/Info.visible = !$CanvasLayer/Info.visible
		return

	# Handle auto evolution toggle
	if event.is_action_pressed("auto_evolution") or (event is InputEventKey and event.keycode == KEY_A and event.pressed and not event.echo):
		toggle_auto_evolution()

	if event.is_action_pressed("config") or (event is InputEventKey and event.keycode == KEY_C and event.pressed and not event.echo):
		if game_active:
			config_window_visible = !config_window_visible
			$CanvasLayer/Config.visible = config_window_visible
			
			# Apply configuration when closing the window
			if !config_window_visible:
				$CanvasLayer/Config.apply_configuration()

	# Only process game inputs if game is active
	if not game_active:
		return

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
		elif current_placement_type == PlacementType.TANK:
			current_placement_type = PlacementType.SAND_BIOME
			print("Placement type: Sand Biome")
		elif current_placement_type == PlacementType.SAND_BIOME:
			current_placement_type = PlacementType.WATER_BIOME
			print("Placement type: Water Biome")
		elif current_placement_type == PlacementType.WATER_BIOME:
			current_placement_type = PlacementType.BOMB
			print("Placement type: Bomb")
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
	
	# Spawn fighter jet when J is pressed
	if event.is_action_pressed("jet_appear") or (event is InputEventKey and event.keycode == KEY_J and event.pressed and not event.echo):
		spawn_fighter_jet()
	
	if event.is_action_pressed("spawn_ufo") or (event is InputEventKey and event.keycode == KEY_H and event.pressed and not event.echo):
		spawn_random_ufo()
		
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
					
		# Update jet debug visualization
		for jet in jets:
			jet.set_debug_visibility(debug_mode)
	
	# Place entity or rigid body at current position
	if event.is_action_pressed("place_entity") and placement_mode:
		place_at_preview()

# Spawn a new fighter jet
func spawn_fighter_jet() -> void:
	# Choose a random team
	var random_team_index = randi() % team_names.size()
	var team_name = team_names[random_team_index]
	var color = teams[team_name]
	
	# Choose a random starting position and direction
	var start_pos: Vector2i
	var direction: Vector2i
	
	# Randomly choose which edge to start from
	var edge = randi() % 4
	
	match edge:
		0:  # Top edge
			start_pos = Vector2i(randi() % grid_size.x, 0)
			direction = Vector2i(0, 1)  # Moving down
		1:  # Right edge
			start_pos = Vector2i(grid_size.x - 1, randi() % grid_size.y)
			direction = Vector2i(-1, 0)  # Moving left
		2:  # Bottom edge
			start_pos = Vector2i(randi() % grid_size.x, grid_size.y - 1)
			direction = Vector2i(0, -1)  # Moving up
		3:  # Left edge
			start_pos = Vector2i(0, randi() % grid_size.y)
			direction = Vector2i(1, 0)  # Moving right
	
	# Create the jet
	var jet = jet_scene.instantiate() as FighterJet
	
	# Initialize the jet
	jet.initialize(color, team_name, start_pos, direction, self)
	
	# Apply configuration
	apply_jet_config(jet)

	# Connect signal for when jet exits grid
	jet.connect("jet_exited", on_jet_exited)
	
	add_child(jet)
	jets.append(jet)
	
	print("Fighter jet spawned for team: ", team_name, " at position: ", start_pos, " moving in direction: ", direction)

# Handle jet exiting the grid
func on_jet_exited(jet: FighterJet) -> void:
	if not jets_to_remove.has(jet):
		jets_to_remove.append(jet)

# Remove a jet
func remove_jet(jet: FighterJet) -> void:
	# Remove from jets array
	var index = jets.find(jet)
	if index != -1:
		jets.remove_at(index)
	
	# Free the jet node
	jet.queue_free()
	print("Fighter jet exited the grid")

# Create a bomb at a specific position
func create_bomb(pos: Vector2i, team_name: String) -> void:
	var bomb = bomb_scene.instantiate() as Bomb
	
	# Initialize the bomb
	bomb.initialize(pos)
	
	# Apply configuration
	apply_bomb_config(bomb)

	# Connect explosion signal
	bomb.connect("bomb_exploded", on_bomb_exploded)
	
	add_child(bomb)
	bombs.append(bomb)
	
	print("Bomb dropped at position: ", pos, " by team: ", team_name)

# Handle bomb explosion
func on_bomb_exploded(bomb: Bomb, explosion_positions: Array) -> void:
	# Add to removal queue
	if not bombs_to_remove.has(bomb):
		bombs_to_remove.append(bomb)
	
	# Create a list of objects to destroy
	var objects_to_destroy = []
	
	# Check each position in the explosion area
	for pos in explosion_positions:
		var pos_string = str(pos.x) + "," + str(pos.y)
		if occupied_positions.has(pos_string):
			var object = occupied_positions[pos_string]
			
			# Determine what kind of object it is
			if object is Entity and object.visible:
				objects_to_destroy.append({
					"type": "entity",
					"object": object,
					"position": pos,
					"team": object.team
				})
			elif object is RigidBody:
				objects_to_destroy.append({
					"type": "rigid_body",
					"object": object,
					"position": pos,
					"team": object.team
				})
			elif object is House:
				var house = object as House
				objects_to_destroy.append({
					"type": "house",
					"object": house,
					"position": pos,
					"team": house.team,
					"entities_inside": house.entities_inside.duplicate()
				})
			elif object is Tank and not object.is_dead:
				objects_to_destroy.append({
					"type": "tank",
					"object": object,
					"position": pos,
					"team": object.team
				})
				
	# Add objects to the destruction queue
	destruction_queue.append_array(objects_to_destroy)
	
	# Create remains at explosion positions
	for pos in explosion_positions:
		# Check if the position is valid and not already marked for remains
		if pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y:
			var pos_string = str(pos.x) + "," + str(pos.y)
			if not pending_remains.has(pos_string):
				pending_remains[pos_string] = {
					"position": pos,
					"team": bomb.team  # Use bomb's team for remains
				}
	
	# Spawn plague cells after explosion
	plague_manager.spawn_initial_plague(explosion_positions, bomb.plague_spawn_count, plague_scene)
	# print statement to include plague info
	print("Bomb exploded at position: ", bomb.position_in_grid, " affecting ", objects_to_destroy.size(), " objects and spawning ", bomb.plague_spawn_count, " plague cells")

func process_plagues() -> void:
	plague_manager.process_plague_turn(plague_scene)

# Process jets movement and bombing
func process_jets() -> void:
	for jet in jets:
		# Check for targets in vision before moving
		var target_pos = jet.check_vision_for_targets(occupied_positions, grid_size)
		
		# If a target was found, drop a bomb
		if target_pos.x >= 0 and target_pos.y >= 0:
			create_bomb(target_pos, jet.team)
		
		# Move the jet (returns false if jet exits grid)
		if not jet.move():
			continue  # Jet will be removed by signal handler
		
		# Update debug visualization if needed
		if debug_mode:
			var vision = jet.calculate_vision_pattern()
			jet.vision_visualizer.show_vision_area(vision)
	
	# Remove jets that have exited the grid
	for jet in jets_to_remove:
		remove_jet(jet)
	jets_to_remove.clear()

# Process bombs countdown
func process_bombs() -> void:
	for bomb in bombs:
		# Process turn returns true if bomb exploded
		if bomb.process_turn():
			continue  # Bomb will be removed by signal handler
	
	# Remove exploded bombs
	for bomb in bombs_to_remove:
		# Remove from bombs array
		var index = bombs.find(bomb)
		if index != -1:
			bombs.remove_at(index)
		
		# Free the bomb node
		bomb.queue_free()
	bombs_to_remove.clear()

func process_iteration() -> void:
	# Update occupied positions for collision detection
	update_occupied_positions()
	
	# First, process any pending remains aging
	process_remains()
	
	# Process plague cells - add this after process_remains() but before process_bombs()
	process_plagues()
	
	# Process bombs and jets
	process_bombs()
	process_jets()
	
	# Check which entities are in sand biomes and update their movement flags
	for entity in entities:
		if not entity.is_dead and entity.visible:
			# Check if entity is on a sand biome
			var pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
			entity.is_in_sand = biomes.has(pos_string) and biomes[pos_string] is SandBiome
			entity.is_in_water = biomes.has(pos_string) and biomes[pos_string] is WaterBiome
			
			# For entities in sand, flip the movement flag each turn
			if entity.is_in_sand:
				entity.can_move_in_sand = !entity.can_move_in_sand

			if entity.is_in_water:
				print("WARNING: Entity found in water, this shouldn't happen!")
	
	# First check for reproduction opportunities
	check_for_reproduction()
	
	# Check for entities entering houses
	check_for_house_entries()
	
	# Process entities leaving houses
	process_house_exits()
	
	# Check for tank-to-tank combat
	check_for_tank_combat()
	
	process_ufos()
	
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
		
		# Use the new hunting behavior instead of random movement
		tank.move_with_hunting(grid_size, occupied_positions)
		
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
			
			# Check if the entity is allowed to move this turn (sand effect)
			var can_move = true
			if entity.is_in_sand:
				can_move = entity.can_move_in_sand
			
			if can_move:
				# Get current position and remove from occupied positions
				var old_pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
				occupied_positions.erase(old_pos_string)
				
				# Use AI movement instead of random movement
				entity.move_with_ai(grid_size, occupied_positions)
				
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
				
		# Update the debug visualization for jets
		for jet in jets:
			var vision = jet.calculate_vision_pattern()
			jet.vision_visualizer.show_vision_area(vision)

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
	var color
	
	# Check if team_name exists in teams dictionary
	if teams.has(team_name):
		color = teams[team_name]
	else:
		# Default color for unknown teams (like "None")
		color = Color(0.5, 0.5, 0.5)  # Grey as default
	
	# Initialize the remains
	remain.initialize(color, team_name)
	remain.position_in_grid = pos
	remain.global_position = Vector2(pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
							pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	add_child(remain)
	remains.append(remain)
	
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
				# Check if entity is fleeing (prioritize entry when threatened)
				var should_enter = entity.is_fleeing
				
				# If not fleeing, use normal chance-based entry
				if not should_enter:
					should_enter = house.try_add_entity(entity)
				else:
					# Always try to enter when fleeing
					should_enter = house.try_add_entity(entity)
				
				if should_enter:
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
			
			# Check if there are enemy tanks near the house
			var enemy_tanks_nearby = false
			var house_area = []
			
			# Create a slightly extended area around the house to check
			for x in range(-3, 4):
				for y in range(-3, 4):
					var check_pos = house.position_in_grid + Vector2i(x, y)
					# Skip if outside grid
					if check_pos.x < 0 or check_pos.x >= grid_size.x or check_pos.y < 0 or check_pos.y >= grid_size.y:
						continue
					house_area.append(check_pos)
			
			# Check if any enemy tanks are in this area
			for tank in tanks:
				if tank.is_dead or tank.team == house.team:
					continue
					
				if house_area.has(tank.position_in_grid):
					enemy_tanks_nearby = true
					break
			
			# If enemy tanks are nearby, entities stay inside for safety
			if enemy_tanks_nearby:
				# Skip exit attempt
				continue
			
			# Normal exit procedure if no threats
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
	# Skip entities in sand biomes
	for entity in entities:
		if not entity.is_dead and entity.is_adult() and entity.visible and not entity.is_in_sand:
			var pos_string = str(entity.position_in_grid.x) + "," + str(entity.position_in_grid.y)
			adults_by_position[pos_string] = entity
	
	# Check each adult entity for potential reproduction
	# Also skip entities in sand biomes
	for entity in entities:
		if entity.is_dead or not entity.is_adult() or entity.had_reproduction_this_turn or not entity.visible or entity.is_in_sand:
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

		# Apply configuration settings to the child entity
		apply_entity_config(child) 
		
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
	# Don't place if game is not active
	if not game_active:
		return

	var grid_pos = placement_preview.position_in_grid
	var pos_string = str(grid_pos.x) + "," + str(grid_pos.y)
	
	# For biomes, we don't need to check if position is occupied since they can coexist with entities
	if current_placement_type == PlacementType.SAND_BIOME:
		# Check if there's already a biome at this position
		if biomes.has(pos_string):
			print("Biome already exists at this position, replacing it")
			# Remove existing biome
			if biomes[pos_string] != null:
				biomes[pos_string].queue_free()
		
		# Create a new sand biome tile at the preview position
		var sand = sand_scene.instantiate() as SandBiome
		
		# Make sure the texture is set
		if sand.sprite == null:
			print("WARNING: Sand sprite texture is not set! Check the inspector.")
			if placement_preview is SandBiome and placement_preview.sprite != null:
				sand.sprite = placement_preview.sprite
		
		# Initialize with position
		sand.initialize(grid_pos)
		add_child(sand)
		biomes[pos_string] = sand
		
		print("Sand biome placed at position: ", grid_pos)
		return
	elif current_placement_type == PlacementType.WATER_BIOME:
		# Check if there's already a biome at this position
		if biomes.has(pos_string):
			print("Biome already exists at this position, replacing it")
			# Remove existing biome
			if biomes[pos_string] != null:
				biomes[pos_string].queue_free()
		
		# Create a new water biome tile at the preview position
		var water = water_scene.instantiate() as WaterBiome
		
		# Make sure the texture is set
		if water.sprite == null:
			print("WARNING: Water sprite texture is not set! Check the inspector.")
			if placement_preview is WaterBiome and placement_preview.sprite != null:
				water.sprite = placement_preview.sprite
		
		# Initialize with position
		water.initialize(grid_pos)
		add_child(water)
		biomes[pos_string] = water
		
		print("Water biome placed at position: ", grid_pos)
		return
	
	elif current_placement_type == PlacementType.BOMB:
		# Check if the position is already occupied
		if occupied_positions.has(pos_string):
			print("Cannot place: position already occupied")
			return
		
		# Create a new bomb at the preview position
		var bomb = bomb_scene.instantiate() as Bomb
		bomb.initialize(grid_pos)

		apply_bomb_config(bomb)

		# Connect explosion signal
		bomb.connect("bomb_exploded", on_bomb_exploded)
		add_child(bomb)
		bombs.append(bomb)
		# Mark this position as occupied immediately
		occupied_positions[pos_string] = bomb
		print("Bomb placed at position: ", grid_pos)
		return
	# For other objects, check if the position is already occupied
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
			
			entity.entity_color = color
			entity.team = team_name
			
		entity.position_in_grid = placement_preview.position_in_grid
		entity.global_position = Vector2(entity.position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
									entity.position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
		
		# Set gender according to current selection
		entity.gender = current_gender
		entity.update_sprite_for_age_and_gender()
		
		# Apply configuration settings to the entity
		apply_entity_config(entity)

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
		
		apply_house_config(house)

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
		
		apply_tank_config(tank)

		add_child(tank)
		tanks.append(tank)
		
		# Mark this position as occupied immediately
		occupied_positions[pos_string] = tank
		
		# If debug mode is on, show vision area
		if debug_mode:
			tank.set_debug_visibility(true)
			tank.update_possible_moves(grid_size, occupied_positions)


func spawn_random_ufo() -> void:
	# First find all valid positions (empty cells with at least 3 empty adjacent cells)
	var valid_positions = []
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var pos = Vector2i(x, y)
			var pos_string = str(pos.x) + "," + str(pos.y)
			
			# Skip if position is already occupied
			if occupied_positions.has(pos_string):
				continue
			
			# Count adjacent empty cells
			var empty_adjacent = 0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
						
					var adjacent_pos = pos + Vector2i(dx, dy)
					
					# Skip if out of bounds
					if adjacent_pos.x < 0 or adjacent_pos.x >= grid_size.x or adjacent_pos.y < 0 or adjacent_pos.y >= grid_size.y:
						continue
					
					var adjacent_pos_string = str(adjacent_pos.x) + "," + str(adjacent_pos.y)
					if not occupied_positions.has(adjacent_pos_string):
						empty_adjacent += 1
			
			# Add to valid positions if there are at least 3 empty adjacent cells
			if empty_adjacent >= 3:
				valid_positions.append(pos)
	
	# If no valid positions, print a message and return
	if valid_positions.size() == 0:
		print("Cannot spawn UFO: no valid positions with enough empty adjacent cells")
		return
	
	# Choose a random valid position
	var random_index = randi() % valid_positions.size()
	var ufo_pos = valid_positions[random_index]
	
	# Choose a random team
	var random_team_index = randi() % team_names.size()
	var team_name = team_names[random_team_index]
	var color = teams[team_name]
	
	# Create the UFO
	var ufo = ufo_scene.instantiate() as UFO
	
	# Initialize the UFO with position and game reference
	ufo.initialize(color, team_name, ufo_pos, self)

	apply_ufo_config(ufo)
	
	# Set global position based on grid position
	ufo.global_position = Vector2(ufo_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
							ufo_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Randomize number of people to spawn (1-3)
	ufo.max_people_spawned = randi() % 3 + 1
	
	# Connect disappearance signal
	ufo.connect("ufo_disappeared", on_ufo_disappeared)
	
	add_child(ufo)
	ufos.append(ufo)
	
	print("UFO spawned for team: ", team_name, " at position: ", ufo_pos)
	
	
	
# Add this function to process UFOs each iteration
func process_ufos() -> void:
	# First, ensure all UFO positions are marked as occupied
	for ufo in ufos:
		var pos_string = str(ufo.position_in_grid.x) + "," + str(ufo.position_in_grid.y)
		occupied_positions[pos_string] = ufo
	
	for ufo in ufos:
		# Try to spawn people around the UFO
		try_spawn_ufo_entities(ufo)
		
		# Process round counter
		if ufo.process_round():
			# UFO should disappear
			ufos_to_remove.append(ufo)
	
	# Remove UFOs that have completed their time
	for ufo in ufos_to_remove:
		remove_ufo(ufo)
	ufos_to_remove.clear()

# Check which biome an entity is on (if any)
func get_biome_at_position(pos: Vector2i) -> Node2D:
	var pos_string = str(pos.x) + "," + str(pos.y)
	if biomes.has(pos_string):
		return biomes[pos_string]
	return null

# Apply biome effects to an entity
func apply_biome_effects(entity: Entity) -> void:
	var biome = get_biome_at_position(entity.position_in_grid)
	
	# Reset all biome-related flags first
	entity.is_in_sand = false
	
	if biome is SandBiome:
		# Mark entity as being in sand
		entity.is_in_sand = true
		
		# Visual indication will be handled in entity's _process
		# Movement restriction is handled in process_iteration
		
		# Debug output
		if debug_mode:
			print("Entity on sand biome - movement status: ", "Can move" if entity.can_move_in_sand else "Stuck")
			
	# Other biome types can be added here in the future
	# elif biome is WaterBiome:
	#     handle water effects
	# etc.

# Add this function to handle spawning entities from UFOs
func try_spawn_ufo_entities(ufo: UFO) -> void:
	# Get all empty adjacent cells
	var empty_cells = []
	
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
				
			var adjacent_pos = ufo.position_in_grid + Vector2i(x, y)
			
			# Skip if out of bounds
			if adjacent_pos.x < 0 or adjacent_pos.x >= grid_size.x or adjacent_pos.y < 0 or adjacent_pos.y >= grid_size.y:
				continue
			
			var pos_string = str(adjacent_pos.x) + "," + str(adjacent_pos.y)
			if not occupied_positions.has(pos_string):
				empty_cells.append(adjacent_pos)
	
	# If no empty cells, UFO should disappear
	if empty_cells.size() == 0:
		ufos_to_remove.append(ufo)
		return
	
	# Shuffle the empty cells to randomize spawning
	empty_cells.shuffle()
	
	# Try to spawn entities until we reach the max for this round or run out of spaces
	for pos in empty_cells:
		if ufo.spawn_entity(pos, entity_scene, self):
			# If we've reached max spawns, stop
			if ufo.people_spawned_this_round >= ufo.max_people_spawned:
				break

# Add this function to handle UFO removal
func remove_ufo(ufo: UFO) -> void:
	# Remove from our UFOs array
	var index = ufos.find(ufo)
	if index != -1:
		ufos.remove_at(index)
	
	# The occupied position is already cleared in the UFO's process_round method
	# when remaining_rounds reaches 0
	
	# Free the UFO node
	ufo.queue_free()
	print("UFO disappeared from position: ", ufo.position_in_grid)

# Signal handler for UFO disappearance
func on_ufo_disappeared(ufo: UFO) -> void:
	if not ufos_to_remove.has(ufo):
		ufos_to_remove.append(ufo)

func is_water_biome(pos: Vector2i) -> bool:
	var pos_string = str(pos.x) + "," + str(pos.y)
	
	if biomes.has(pos_string):
		return biomes[pos_string] is WaterBiome
	
	return false

# Apply entity configuration to a new entity
func apply_entity_config(entity: Entity) -> void:
	var config = $CanvasLayer/Config.get_entity_config()
	
	# Apply config values to entity
	entity.LIFESPAN = config["lifespan"]
	entity.BIRTH_AGE = config["birth_age"]
	entity.FERTILITY = config["fertility"]
	entity.FERTILITY_DECREASE = config["fertility_decrease"]
	
	# Make sure these are applied to the entity's current values too
	entity.lifespan = entity.LIFESPAN
	entity.age = entity.BIRTH_AGE
	entity.reproduction_chance = entity.FERTILITY
	entity.reproduction_decrease = entity.FERTILITY_DECREASE
	
	# Update sprite based on new age configuration
	entity.update_sprite_for_age_and_gender()

# Apply tank configuration to a new tank
func apply_tank_config(tank: Tank) -> void:
	var config = $CanvasLayer/Config.get_tank_config()
	
	# Apply config values to tank
	tank.HUNTING_COOLDOWN = config["hunting_cooldown"]
	
	# Make sure these are applied to the tank's current values too
	tank.hunting_cooldown = tank.HUNTING_COOLDOWN

# Apply house configuration to a new house
func apply_house_config(house: House) -> void:
	var config = $CanvasLayer/Config.get_house_config()
	
	# Apply config values to house
	house.MAX_CAPACITY = config["capacity"]
	
	# Make sure these are applied to the house's current values too
	house.max_capacity = house.MAX_CAPACITY


# Apply UFO configuration to a new UFO
func apply_ufo_config(ufo: UFO) -> void:
	var config = $CanvasLayer/Config.get_ufo_config()
	
	# Apply config values to UFO
	ufo.MAX_PRESENCE = config["max_presence"]
	ufo.MAX_HUMANS_AMOUNT = config["max_humans_amount"]
	
	# Make sure these are applied to the UFO's current values too
	ufo.remaining_rounds = ufo.MAX_PRESENCE
	ufo.max_people_spawned = ufo.MAX_HUMANS_AMOUNT

# Apply bomb configuration to a new bomb
func apply_bomb_config(bomb: Bomb) -> void:
	var config = $CanvasLayer/Config.get_bomb_config()
	
	# Apply config values to bomb
	bomb.COUNTDOWN = config["countdown"]
	bomb.EXPLOSION_RADIUS = config["explosion_radius"]
	bomb.PLAGUE_CELLS = config["plague_cells"]
	
	# Make sure these are applied to the bomb's current values too
	bomb.countdown = bomb.COUNTDOWN
	bomb.explosion_radius = bomb.EXPLOSION_RADIUS
	bomb.plague_cells = bomb.PLAGUE_CELLS

# Apply jet configuration to a new jet
func apply_jet_config(jet: FighterJet) -> void:
	var config = $CanvasLayer/Config.get_jet_config()
	
	# Apply config values to jet
	jet.SPEED = config["speed"]
	jet.cooldown_duration = config["cooldown_duration"]
	
	# Make sure these are applied to the jet's current values too
	jet.speed = jet.SPEED
