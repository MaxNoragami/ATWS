extends Node2D

class_name Bomb

@export var COUNTDOWN : int = 3
@export var EXPLOSION_RADIUS : int = 1
@export var PLAGUE_CELLS : int = 7

@export var sprite: Texture2D
var entity_color: Color = Color(0.0, 0.0, 0.0)  # Black color for bombs
var team: String = "None"
var position_in_grid: Vector2i
var countdown: int = COUNTDOWN  # Explodes after 3 iterations
var atlas_x: int = 45  # Atlas coordinates for bomb texture - updated to (45,9)
var atlas_y: int = 9
var explosion_radius: int = EXPLOSION_RADIUS  # How many cells around the bomb will be affected
var plague_spawn_count: int  # Random number of plague cells to spawn (0-7)
var plague_cells : int = PLAGUE_CELLS

signal bomb_exploded(bomb, positions)

func _ready() -> void:
	countdown = COUNTDOWN
	explosion_radius = EXPLOSION_RADIUS
	plague_cells = PLAGUE_CELLS

	z_index = 7  # Above most objects but below jets
	
	# Create sprite
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)
	
	# Apply color tint
	sprite_node.modulate = entity_color
	
	add_child(sprite_node)
	
	# Determine random number of plague cells to spawn (0-7)
	plague_spawn_count = randi() % (plague_cells + 1)  # 0 to 7

# Initialize the bomb with custom parameters
func initialize(grid_pos: Vector2i) -> void:
	entity_color = Color(0.0, 0.0, 0.0)  # Force black color
	team = "None"  # Bombs don't belong to any team
	position_in_grid = grid_pos
	
	# Set global position
	global_position = Vector2(position_in_grid.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
						  position_in_grid.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Update sprite color if it exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = entity_color

# Process a game turn - return true if bomb exploded
func process_turn() -> bool:
	countdown -= 1
	
	# Visual feedback of countdown (make it blink faster as countdown decreases)
	var sprite_node = get_child(0) as Sprite2D
	if sprite_node:
		if countdown == 2:
			# Slow blinking
			var blink_sequence = func(): 
				var t = Time.get_ticks_msec() / 500.0
				return sin(t) > 0
			sprite_node.visible = blink_sequence.call()
		elif countdown == 1:
			# Fast blinking
			var blink_sequence = func(): 
				var t = Time.get_ticks_msec() / 250.0
				return sin(t) > 0
			sprite_node.visible = blink_sequence.call()
	
	if countdown <= 0:
		# Bomb explodes
		explode()
		return true
	return false

# Calculate explosion area
func calculate_explosion_area(grid_size: Vector2i) -> Array[Vector2i]:
	var explosion_area: Array[Vector2i] = []
	
	# Include bomb's own position
	explosion_area.append(position_in_grid)
	
	# Add surrounding cells based on explosion radius
	for x in range(-explosion_radius, explosion_radius + 1):
		for y in range(-explosion_radius, explosion_radius + 1):
			if x == 0 and y == 0:
				continue  # Skip bomb's position (already added)
			
			var pos = Vector2i(position_in_grid.x + x, position_in_grid.y + y)
			
			# Check if position is within grid bounds
			if pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y:
				explosion_area.append(pos)
	
	return explosion_area

# Handle explosion
func explode() -> void:
	# Calculate explosion area
	var explosion_area = calculate_explosion_area(Game.CELLS_AMOUNT)
	
	# Emit signal with explosion area
	emit_signal("bomb_exploded", self, explosion_area)
