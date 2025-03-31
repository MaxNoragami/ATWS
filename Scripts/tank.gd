extends Node2D

class_name Tank

@export var sprite: Texture2D
var entity_color: Color = Color(1.0, 1.0, 1.0)  # Default color (white)
var team: String = "None"
var position_in_grid: Vector2i
var facing_direction: Vector2i = Vector2i(0, -1)  # Default facing up

# Atlas coordinates for different directions
var sprite_atlas = {
	Vector2i(0, -1): Vector2i(9, 20),   # Up
	Vector2i(0, 1): Vector2i(10, 20),   # Down
	Vector2i(1, 0): Vector2i(11, 20),   # Right
	Vector2i(-1, 0): Vector2i(11, 20)   # Left (same as right but flipped)
}

var vision_pattern = []  # Will be populated based on direction
var movement: TankMovement
var debug_visualizer: TankVisionVisualizer
var is_dead: bool = false

# Signal for when this tank is destroyed
signal tank_destroyed(tank)

func _init(color: Color = Color(1.0, 1.0, 1.0), team_name: String = "None") -> void:
	entity_color = color
	team = team_name

func _ready() -> void:
	z_index = 6
	# Create sprite
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	
	# Apply color tint
	sprite_node.modulate = entity_color
	
	add_child(sprite_node)
	
	# Set initial sprite based on direction
	update_sprite_for_direction()
	
	# Add movement component
	movement = TankMovement.new()
	add_child(movement)
	
	# Add debug visualizer
	debug_visualizer = TankVisionVisualizer.new(self)
	add_child(debug_visualizer)
	
	# Calculate initial vision pattern
	calculate_vision_pattern()

# Initialize the tank with custom parameters
func initialize(color: Color, team_name: String) -> void:
	entity_color = color
	team = team_name
	
	# Update the sprite if it already exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = entity_color

# Update possible moves and debug visualization
func update_possible_moves(grid_size: Vector2i, occupied_positions: Dictionary) -> void:
	var moves = movement.calculate_possible_moves(grid_size, occupied_positions)
	# Show both vision area and kill zone in debug visualization
	debug_visualizer.show_vision_and_kill_area(calculate_vision_pattern(), calculate_kill_zone(), grid_size)

# Calculate vision pattern based on current direction
func calculate_vision_pattern() -> Array[Vector2i]:
	# Create a properly typed array for the result
	var result: Array[Vector2i] = []
	
	# Instead of using rotation formulas which might be causing issues,
	# we'll define each pattern explicitly
	
	if facing_direction == Vector2i(0, -1):  # Up
		# Original pattern
		result = [
			# Row 1 (furthest ahead)
			Vector2i(0, -3),
			# Row 2
			Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2),
			# Row 3
			Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1),
			# Row 4 (tank is here at 0,0)
			Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 0),
			# Row 5 (behind tank)
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
		]
	elif facing_direction == Vector2i(0, 1):  # Down
		# Down pattern - mirrored from up
		result = [
			# Row 1 (furthest ahead - now below tank)
			Vector2i(0, 3),
			# Row 2
			Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2),
			# Row 3
			Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			# Row 4 (tank is here at 0,0)
			Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 0),
			# Row 5 (behind tank - now above)
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
		]
	elif facing_direction == Vector2i(1, 0):  # Right
		# Right pattern
		result = [
			# Furthest right
			Vector2i(3, 0),
			# Second column
			Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1),
			# Third column 
			Vector2i(1, -2), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2),
			# Fourth column (tank is at 0,0)
			Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 2),
			# Fifth column (behind tank)
			Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1)
		]
	elif facing_direction == Vector2i(-1, 0):  # Left
		# Left pattern
		result = [
			# Furthest left
			Vector2i(-3, 0),
			# Second column
			Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1),
			# Third column
			Vector2i(-1, -2), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(-1, 2),
			# Fourth column (tank is at 0,0)
			Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 1), Vector2i(0, 2),
			# Fifth column (behind tank)
			Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)
		]
	
	# Translate pattern to be relative to tank's position
	var absolute_result: Array[Vector2i] = []
	for pos in result:
		absolute_result.append(position_in_grid + pos)
	
	return absolute_result

# Calculate kill zone based on current direction
func calculate_kill_zone() -> Array[Vector2i]:
	# Create a properly typed array for the result
	var result: Array[Vector2i] = []
	
	# Kill zone pattern as shown in the image:
	# OOXOO
	# OXXXO
	# XXXXX
	# SSTSS
	# OSSSO
	
	if facing_direction == Vector2i(0, -1):  # Up
		result = [
			# Row 1 (furthest ahead)
			Vector2i(0, -3),
			# Row 2
			Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2),
			# Row 3 (in front of tank)
			Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)
		]
	elif facing_direction == Vector2i(0, 1):  # Down
		result = [
			# Row 1 (furthest ahead - now below tank)
			Vector2i(0, 3),
			# Row 2
			Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2),
			# Row 3 (in front of tank)
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)
		]
	elif facing_direction == Vector2i(1, 0):  # Right
		result = [
			# Furthest right
			Vector2i(3, 0),
			# Second column
			Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1),
			# Third column (in front of tank)
			Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1)
		]
	elif facing_direction == Vector2i(-1, 0):  # Left
		result = [
			# Furthest left
			Vector2i(-3, 0),
			# Second column
			Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(-2, 1),
			# Third column (in front of tank)
			Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1)
		]
	
	# Translate pattern to be relative to tank's position
	var absolute_result: Array[Vector2i] = []
	for pos in result:
		absolute_result.append(position_in_grid + pos)
	
	return absolute_result
	
# Check for entities in vision field and destroy them
func destroy_entities_in_vision(entities: Array, rigid_bodies: Array, houses: Array, tanks: Array, occupied_positions: Dictionary, grid_size: Vector2i) -> Array:
	var destroyed_objects = []
	var kill_zone = calculate_kill_zone()
	
	# Create a dictionary for fast lookup of kill zone positions
	var kill_positions = {}
	for pos in kill_zone:
		var pos_string = str(pos.x) + "," + str(pos.y)
		kill_positions[pos_string] = true
	
	# Check each position in kill zone
	for pos in kill_zone:
		# Skip positions outside grid
		if pos.x < 0 or pos.x >= grid_size.x or pos.y < 0 or pos.y >= grid_size.y:
			continue
			
		var pos_string = str(pos.x) + "," + str(pos.y)
		if occupied_positions.has(pos_string):
			var object = occupied_positions[pos_string]
			
			# Destroy only enemy entities/objects (different team)
			if object.team != team:
				if object is Entity and object.visible:
					# Found an enemy entity in kill zone - mark for destruction
					destroyed_objects.append({
						"type": "entity",
						"object": object,
						"position": pos,
						"team": object.team
					})
				elif object is Tank and not object.is_dead:
					# Found an enemy tank in kill zone - mark for destruction
					destroyed_objects.append({
						"type": "tank",
						"object": object,
						"position": pos,
						"team": object.team
					})
	
	return destroyed_objects

# Check if the position the tank is moving to contains a destroyable object
func check_for_destroyable_at_position(pos: Vector2i, occupied_positions: Dictionary) -> Dictionary:
	var pos_string = str(pos.x) + "," + str(pos.y)
	if occupied_positions.has(pos_string):
		var object = occupied_positions[pos_string]
		
		# Destroy only enemy objects (different team)
		if object.team != team:
			if object is RigidBody:
				return {
					"type": "rigid_body",
					"object": object,
					"position": pos,
					"team": object.team
				}
			elif object is House:
				return {
					"type": "house",
					"object": object,
					"position": pos,
					"team": object.team,
					"entities_inside": object.entities_inside.duplicate()
				}
			elif object is Tank:
				return {
					"type": "tank",
					"object": object,
					"position": pos,
					"team": object.team
				}
	
	return {}  # Empty dict if nothing to destroy

# Delegate to movement component
func move_randomly(grid_size: Vector2i, occupied_positions: Dictionary) -> void:
	var old_direction = facing_direction
	movement.move_randomly(grid_size, occupied_positions)
	
	# If direction changed, update sprite
	if old_direction != facing_direction:
		update_sprite_for_direction()
	
	# Update debug visualization with new vision pattern
	if debug_visualizer and debug_visualizer.is_visible:
		debug_visualizer.show_vision_and_kill_area(calculate_vision_pattern(), calculate_kill_zone(), grid_size)

# Update sprite based on current direction
func update_sprite_for_direction() -> void:
	var atlas_coords = sprite_atlas[facing_direction]
	
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
