extends Node2D

@export var entity_scene: PackedScene
var entities: Array[Entity] = []
var grid_size = Vector2i(Game.CELLS_AMOUNT.x, Game.CELLS_AMOUNT.y)

var teams = {
	"Blue": Color(0.0, 0.0, 1.0),
	"Green": Color(0.0, 1.0, 0.0),
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
var placement_preview: Entity = null

# Debug mode
var debug_mode = false
var entities_to_remove: Array[Entity] = []

func _ready() -> void:
	# Create a preview entity for placement mode
	create_placement_preview()

func create_placement_preview() -> void:
	placement_preview = entity_scene.instantiate() as Entity
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	
	# Initialize with current team color but make it transparent
	var preview_color = Color(color.r, color.g, color.b, 0.5)  # 50% transparency
	placement_preview._init(preview_color, team_name)
	placement_preview.visible = false  # Hide initially until placement mode is activated
	
	# Set gender for preview
	placement_preview.gender = current_gender
	placement_preview.update_sprite_for_age_and_gender()
	
	add_child(placement_preview)

func _process(delta: float) -> void:
	if placement_mode:
		update_placement_preview()
		
	# Process any pending entity removals
	if entities_to_remove.size() > 0:
		for entity in entities_to_remove:
			remove_entity(entity)
		entities_to_remove.clear()

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
	
	# Also update the team color of the preview
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	var preview_color = Color(color.r, color.g, color.b, 0.5)  # 50% transparency
	
	# Update sprite color (assuming it's the first child)
	if placement_preview.get_child_count() > 0:
		placement_preview.get_child(0).modulate = preview_color

func _input(event) -> void:
	if event.is_action_pressed("next_iteration"):
		process_iteration()
	
	if event.is_action_pressed("switch_team"):
		current_team_index = (current_team_index + 1) % team_names.size()
		print("Current team:", team_names[current_team_index])
		
		# Update preview color if in placement mode
		if placement_mode:
			update_placement_preview()
	
	# Toggle gender for new entities
	if event.is_action_pressed("switch_gender"):
		if current_gender == Entity.Gender.MALE:
			current_gender = Entity.Gender.FEMALE
			print("Gender set to: Female")
		else:
			current_gender = Entity.Gender.MALE
			print("Gender set to: Male")
			
		# Update preview if in placement mode
		if placement_mode and placement_preview:
			placement_preview.gender = current_gender
			placement_preview.update_sprite_for_age_and_gender()
	
	# Toggle placement mode
	if event.is_action_pressed("place_mode"):
		placement_mode = !placement_mode
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
					entity.update_possible_moves(grid_size)
	
	# Place entity at current position
	if event.is_action_pressed("place_entity") and placement_mode:
		place_entity_at_preview()

func process_iteration() -> void:
	# Create a copy of the entities array to safely iterate
	var current_entities = entities.duplicate()
	
	# Process each entity
	for entity in current_entities:
		if not entity.is_dead:
			entity.move_randomly(grid_size)
			entity.age_up()

func on_entity_died(entity) -> void:
	# Add the entity to the removal queue
	if not entities_to_remove.has(entity):
		entities_to_remove.append(entity)

func remove_entity(entity) -> void:
	# Remove from our entities array
	var index = entities.find(entity)
	if index != -1:
		entities.remove_at(index)
	
	# Free the entity node
	entity.queue_free()
	print("Entity died at age: ", entity.age)

func place_entity_at_preview() -> void:
	# Create a new entity at the preview position
	var entity = entity_scene.instantiate() as Entity
	var team_name = team_names[current_team_index]
	var color = teams[team_name]
	
	entity._init(color, team_name)
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
	
	# If debug mode is on, show possible moves
	if debug_mode:
		entity.set_debug_visibility(true)
		entity.update_possible_moves(grid_size)
