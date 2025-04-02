extends Node2D

class_name FighterJet

@export var sprite: Texture2D
var entity_color: Color = Color(1.0, 1.0, 1.0)  # Default color (white)
var team: String = "None"
var position_in_grid: Vector2i
var movement_direction: Vector2i  # Direction of movement (e.g., Vector2i(1, 0) for right)
var vision_visualizer: JetVisionVisualizer

# Atlas coordinates for different directions
var sprite_atlas = {
	"up": Vector2i(13, 21),
	"down": Vector2i(12, 21),
	"right": Vector2i(14, 21),
	"left": Vector2i(14, 21)   # Same as right but flipped
}

# Bomb cooldown
var bomb_cooldown: int = 0
var cooldown_duration: int = 8  # Iterations to wait between bombs

# Reference to the game node
var game_node

# Signal for when jet exits the grid
signal jet_exited(jet)

func _init(color: Color = Color(1.0, 1.0, 1.0), team_name: String = "None") -> void:
	entity_color = color
	team = team_name

func _ready() -> void:
	z_index = 8  # Above tanks, UFOs, etc.
	
	# Create sprite
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	
	# Initial direction and sprite
	if movement_direction.x > 0:  # Right
		sprite_node.region_rect = Rect2(sprite_atlas["right"].x * 16, sprite_atlas["right"].y * 16, 16, 16)
	elif movement_direction.x < 0:  # Left
		sprite_node.region_rect = Rect2(sprite_atlas["left"].x * 16, sprite_atlas["left"].y * 16, 16, 16)
		sprite_node.flip_h = true  # Flip for left direction
	elif movement_direction.y > 0:  # Down
		sprite_node.region_rect = Rect2(sprite_atlas["down"].x * 16, sprite_atlas["down"].y * 16, 16, 16)
	else:  # Up
		sprite_node.region_rect = Rect2(sprite_atlas["up"].x * 16, sprite_atlas["up"].y * 16, 16, 16)
	
	# Apply color tint
	sprite_node.modulate = entity_color
	
	add_child(sprite_node)
	
	# Add vision visualizer
	vision_visualizer = JetVisionVisualizer.new(self)
	add_child(vision_visualizer)

# Initialize the jet with custom parameters and starting position
func initialize(color: Color, team_name: String, start_pos: Vector2i, direction: Vector2i, game_reference) -> void:
	entity_color = color
	team = team_name
	position_in_grid = start_pos
	movement_direction = direction
	game_node = game_reference
	
	# Set global position
	global_position = Vector2(position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
						position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Update sprite if it exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0)
		sprite_node.modulate = entity_color
		update_sprite_for_direction()

# Calculate vision pattern based on current direction
func calculate_vision_pattern() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	if movement_direction.x != 0:  # Horizontal movement (left or right)
		# Vision pattern as per specification:
		#   XXX
		#   XJX
		#   XXX
		for x in range(-1, 2):  # -1, 0, 1
			for y in range(-1, 2):  # -1, 0, 1
				if x == 0 and y == 0:
					continue  # Skip the jet's own position
				result.append(Vector2i(x, y))
	else:  # Vertical movement (up or down)
		# Vision pattern rotated for vertical movement:
		#   XXX
		#   XJX
		#   XXX
		for x in range(-1, 2):  # -1, 0, 1
			for y in range(-1, 2):  # -1, 0, 1
				if x == 0 and y == 0:
					continue  # Skip the jet's own position
				result.append(Vector2i(x, y))
	
	# Translate to absolute grid positions
	var absolute_result: Array[Vector2i] = []
	for pos in result:
		absolute_result.append(position_in_grid + pos)
	
	return absolute_result

# Move the jet across the grid
func move() -> bool:
	# Always skip one grid cell (move 2 cells at once)
	var new_position = position_in_grid + (movement_direction * 2)
	
	# Check if new position is out of grid bounds
	if new_position.x < 0 or new_position.x >= Game.CELLS_AMOUNT.x or \
	   new_position.y < 0 or new_position.y >= Game.CELLS_AMOUNT.y:
		# Jet has exited the grid
		emit_signal("jet_exited", self)
		return false
	
	# Update position
	position_in_grid = new_position
	
	# Update global position
	global_position = Vector2(position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
						position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Decrement bomb cooldown if active
	if bomb_cooldown > 0:
		bomb_cooldown -= 1
	
	return true

# Check vision for targets and drop bombs if needed
func check_vision_for_targets(occupied_positions: Dictionary, grid_size: Vector2i) -> Vector2i:
	# If bomb is on cooldown, don't check for targets
	if bomb_cooldown > 0:
		return Vector2i(-1, -1)
	
	# Get vision area
	var vision = calculate_vision_pattern()
	
	# Check for valid targets in vision
	for cell in vision:
		# Skip if out of bounds
		if cell.x < 0 or cell.x >= grid_size.x or cell.y < 0 or cell.y >= grid_size.y:
			continue
			
		# Check if there's an object at this position
		var pos_string = str(cell.x) + "," + str(cell.y)
		if occupied_positions.has(pos_string):
			var object = occupied_positions[pos_string]
			
			# Valid targets are houses, tanks, and entities
			if (object is House) or (object is Tank and not object.is_dead) or (object is Entity and object.visible):
				# Target found, start bomb cooldown
				bomb_cooldown = cooldown_duration
				return cell  # Return target position for bomb placement
	
	# No valid targets found
	return Vector2i(-1, -1)

# Update sprite based on movement direction
func update_sprite_for_direction() -> void:
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		
		# Reset flip
		sprite_node.flip_h = false
		
		if movement_direction.x > 0:  # Right
			sprite_node.region_rect = Rect2(sprite_atlas["right"].x * 16, sprite_atlas["right"].y * 16, 16, 16)
		elif movement_direction.x < 0:  # Left
			sprite_node.region_rect = Rect2(sprite_atlas["left"].x * 16, sprite_atlas["left"].y * 16, 16, 16)
			sprite_node.flip_h = true  # Flip for left direction
		elif movement_direction.y > 0:  # Down
			sprite_node.region_rect = Rect2(sprite_atlas["down"].x * 16, sprite_atlas["down"].y * 16, 16, 16)
		else:  # Up
			sprite_node.region_rect = Rect2(sprite_atlas["up"].x * 16, sprite_atlas["up"].y * 16, 16, 16)

# Set debug visualization visibility
func set_debug_visibility(visible: bool) -> void:
	vision_visualizer.set_visibility(visible)
