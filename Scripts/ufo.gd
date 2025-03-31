extends Node2D

class_name UFO

signal ufo_disappeared(ufo)

@export var sprite: Texture2D
var ufo_color: Color = Color(1.0, 1.0, 1.0)  # Default white color
var team: String = "None"

var position_in_grid: Vector2i
var remaining_rounds: int = 3
var max_people_spawned: int = 5
var people_spawned_this_round: int = 0

var game_node  # Reference to the game node to access occupied positions

func _init(color: Color = Color(1.0, 1.0, 1.0), team_name: String = "None") -> void:
	ufo_color = color
	team = team_name

func _ready() -> void:
	z_index = 7
	# Create sprite
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	sprite_node.region_rect = Rect2(14 * 16, 20 * 16, 16, 16)
	
	# Apply color tint
	sprite_node.modulate = ufo_color
	
	add_child(sprite_node)

	# Mark this position as occupied
	if game_node:
		var pos_string = str(position_in_grid.x) + "," + str(position_in_grid.y)
		game_node.occupied_positions[pos_string] = self

func initialize(color: Color, team_name: String, grid_pos: Vector2i, game_ref) -> void:
	ufo_color = color
	team = team_name
	position_in_grid = grid_pos
	game_node = game_ref
	
	# Update sprite color if it exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = ufo_color
	
	# Mark the cell as occupied
	if game_node:
		var pos_string = str(position_in_grid.x) + "," + str(position_in_grid.y)
		game_node.occupied_positions[pos_string] = self

# Decrement rounds left and return true if UFO should disappear
func process_round() -> bool:
	remaining_rounds -= 1
	people_spawned_this_round = 0
	
	# If the UFO disappears, free its cell
	if remaining_rounds <= 0 and game_node:
		var pos_string = str(position_in_grid.x) + "," + str(position_in_grid.y)
		game_node.occupied_positions.erase(pos_string)
	
	return remaining_rounds <= 0

# Try to spawn an entity at a given position
func spawn_entity(pos: Vector2i, entity_scene: PackedScene, game_node) -> bool:
	# Check if we've already spawned max people this round
	if people_spawned_this_round >= max_people_spawned:
		return false
	
	# Explicitly prevent spawning on the UFO itself
	if pos == position_in_grid:
		return false
	
	# Check if the target position is occupied
	var pos_string = str(pos.x) + "," + str(pos.y)
	if game_node.occupied_positions.has(pos_string):
		return false  # Position is already occupied by something else
	
	# Create a new entity
	var entity = entity_scene.instantiate() as Entity
	
	# Initialize the entity with UFO team color
	if entity.has_method("initialize"):
		entity.initialize(ufo_color, team)
	else:
		entity.entity_color = ufo_color
		entity.team = team
		
	entity.position_in_grid = pos
	entity.global_position = Vector2(pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
								pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Randomly determine gender
	entity.gender = Entity.Gender.MALE if randf() > 0.5 else Entity.Gender.FEMALE
	entity.update_sprite_for_age_and_gender()
	
	# Set age to 0 (child)
	entity.age = 0
	
	# Connect death signal to game node
	entity.connect("entity_died", game_node.on_entity_died)
	
	game_node.add_child(entity)
	game_node.entities.append(entity)
	
	# Mark this position as occupied
	game_node.occupied_positions[pos_string] = entity
	
	# If debug mode is on, show possible moves
	if game_node.debug_mode:
		entity.set_debug_visibility(true)
		entity.update_possible_moves(game_node.grid_size, game_node.occupied_positions)
	
	people_spawned_this_round += 1
	return true