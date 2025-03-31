extends Node2D

# Entity script
class_name Entity

var is_in_sand: bool = false
var can_move_in_sand: bool = true  # Alternates between true/false when in sand
var is_preview: bool = false
var vision_visualizer: EntityVisionVisualizer

signal entity_died(entity)

@export var sprite: Texture2D
@export var atlas_x: int = 24  # Default to male child
@export var atlas_y: int = 10
var entity_color: Color = Color(1.0, 0.5, 0.5)  # Default color (light red)
var team: String = "None"

# Gender properties
enum Gender { MALE, FEMALE }
var gender: Gender = Gender.MALE

# Age properties
var age: int = 0
var lifespan: int = 100
var age_periods = {
	"child": 0.2,    # 0-19 years (20% of lifespan)
	"adult": 0.6,    # 20-79 years (60% of lifespan)
	"elder": 0.2     # 80-99 years (20% of lifespan)
}

# Reproduction properties
var reproduction_chance: float = 0.5  # Initial reproduction chance
var reproduction_decrease: float = 0.17  # Decrease after reproduction
var had_reproduction_this_turn: bool = false  # Flag to track reproduction in current turn

# Atlas coordinates for different sprites
var sprite_atlas = {
	Gender.MALE: {
		"child": Vector2i(24, 10),
		"adult": Vector2i(29, 10),
		"elder": Vector2i(27, 10)
	},
	Gender.FEMALE: {
		"child": Vector2i(25, 10),
		"adult": Vector2i(30, 10),
		"elder": Vector2i(31, 10)
	}
}

var position_in_grid: Vector2i
var movement: EntityMovement
var debug_visualizer: MoveDebugVisualizer
var is_dead: bool = false

func _init(color: Color = Color(1.0, 0.5, 0.5), team_name: String = "None") -> void:
	entity_color = color
	team = team_name

func _ready() -> void:
	# Create sprite
	z_index = 5
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)
	
	# Apply color tint
	sprite_node.modulate = entity_color
	
	add_child(sprite_node)
	
	# Add movement component
	movement = EntityMovement.new()
	add_child(movement)
	
	# Add debug visualizer
	debug_visualizer = MoveDebugVisualizer.new(self)
	add_child(debug_visualizer)

	# Add vision visualizer
	vision_visualizer = EntityVisionVisualizer.new(self)
	add_child(vision_visualizer)
	
	# Initial age-based sprite update
	update_sprite_for_age_and_gender()

# Visual indicator for entity stuck in sand
func _process(delta: float) -> void:
	# Skip visual effects for preview entities
	if is_preview:
		return
        	
	# Visual indication when entity is in sand and can't move
	if is_in_sand and not can_move_in_sand:
		# Make the entity slightly transparent when it's stuck in sand
		if get_child_count() > 0 and get_child(0) is Sprite2D:
			var sprite_node = get_child(0)
			var original_color = entity_color
			sprite_node.modulate = Color(original_color.r, original_color.g, original_color.b, 0.6)
	else:
		# Normal appearance
		if get_child_count() > 0 and get_child(0) is Sprite2D:
			var sprite_node = get_child(0)
			var original_color = entity_color
			sprite_node.modulate = Color(original_color.r, original_color.g, original_color.b, 1.0)

# Update possible moves and debug visualization
# Modify this function to show both movement and vision debug
func update_possible_moves(grid_size: Vector2i, occupied_positions: Dictionary) -> void:
	var moves = movement.calculate_possible_moves(grid_size, occupied_positions)
	debug_visualizer.show_possible_moves(moves)
	
	# Update vision visualization as well
	var vision = calculate_vision_area()
	vision_visualizer.show_vision_area(vision)

# Delegate to movement component
func move_randomly(grid_size: Vector2i, occupied_positions: Dictionary) -> void:
	movement.move_randomly(grid_size, occupied_positions)
	# Update debug visualization after movement
	update_possible_moves(grid_size, occupied_positions)
	
	# Reset reproduction flag for next turn
	had_reproduction_this_turn = false

# Age by one year
func age_up() -> void:
	age += 1
	if age >= lifespan:
		# Handle death - emit signal before freeing
		is_dead = true
		emit_signal("entity_died", self)
		return
	
	# Update sprite based on new age
	update_sprite_for_age_and_gender()

# Add this function to calculate the vision area based on age period
func calculate_vision_area() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var period = get_age_period()
	
	# Define vision patterns for each age group
	if period == "child":
		# 3x3 square
		for x in range(-1, 2):
			for y in range(-1, 2):
				if not (x == 0 and y == 0):  # Skip entity's position
					result.append(Vector2i(x, y))
	elif period == "elder":
		# 5x5 square with corners removed
		for x in range(-2, 3):
			for y in range(-2, 3):
				if not (x == 0 and y == 0):  # Skip entity's position
					if not ((abs(x) == 2 and abs(y) == 2)):  # Skip corners
						result.append(Vector2i(x, y))
	else:  # adult
		# 7x7 square with outer corners removed
		for x in range(-3, 4):
			for y in range(-3, 4):
				if not (x == 0 and y == 0):  # Skip entity's position
					if not ((abs(x) == 3 and abs(y) == 3) or  # Skip outer corners
							(abs(x) == 3 and abs(y) == 2) or
							(abs(x) == 2 and abs(y) == 3)):
						result.append(Vector2i(x, y))
	
	# Translate to absolute grid positions
	var absolute_result: Array[Vector2i] = []
	for pos in result:
		absolute_result.append(position_in_grid + pos)
	
	return absolute_result

# Check if entity is an adult
func is_adult() -> bool:
	var child_limit = lifespan * age_periods["child"]
	var adult_limit = child_limit + (lifespan * age_periods["adult"])
	return age >= child_limit && age < adult_limit

# Attempt reproduction with another entity
func try_reproduce(other_entity: Entity) -> bool:
	# Can't reproduce if either has already reproduced this turn
	if had_reproduction_this_turn || other_entity.had_reproduction_this_turn:
		return false
		
	# Combined reproduction chance
	var combined_chance = reproduction_chance + other_entity.reproduction_chance
	
	# Roll for reproduction
	if randf() <= combined_chance:
		# Successful reproduction
		had_reproduction_this_turn = true
		other_entity.had_reproduction_this_turn = true
		
		# Decrease reproduction chance
		reproduction_chance = max(0.0, reproduction_chance - reproduction_decrease)
		other_entity.reproduction_chance = max(0.0, other_entity.reproduction_chance - reproduction_decrease)
		
		return true
	
	return false

# Update sprite based on current age and gender
func update_sprite_for_age_and_gender() -> void:
	var period = get_age_period()
	var atlas_coords = sprite_atlas[gender][period]
	update_sprite(atlas_coords.x, atlas_coords.y)

# Get current age period (child, adult, elder)
func get_age_period() -> String:
	var child_limit = lifespan * age_periods["child"]
	var adult_limit = child_limit + (lifespan * age_periods["adult"])
	
	if age < child_limit:
		return "child"
	elif age < adult_limit:
		return "adult"
	else:
		return "elder"

# Switch gender
func switch_gender() -> void:
	if gender == Gender.MALE:
		gender = Gender.FEMALE
	else:
		gender = Gender.MALE
	
	# Update sprite based on new gender
	update_sprite_for_age_and_gender()

# Helper function to update sprite appearance
func update_sprite(new_atlas_x: int, new_atlas_y: int) -> void:
	atlas_x = new_atlas_x
	atlas_y = new_atlas_y
	
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)

# Helper function to set opacity (useful for preview)
func set_opacity(opacity: float) -> void:
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		var current_color = sprite_node.modulate
		sprite_node.modulate = Color(current_color.r, current_color.g, current_color.b, opacity)

	is_preview = true

# Toggle debug visualization
func set_debug_visibility(visible: bool) -> void:
	debug_visualizer.set_visibility(visible)
	vision_visualizer.set_visibility(visible)