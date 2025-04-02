extends Node2D

class_name Plague

@export var sprite: Texture2D
var position_in_grid: Vector2i
var lifetime: int  # How many iterations before disappearing
var atlas_coords = [
	Vector2i(30, 12),
	Vector2i(2, 0),
	Vector2i(6, 0),
	Vector2i(19, 1),
	Vector2i(37, 11)
]
var atlas_x: int  # Current atlas coordinates for plague texture
var atlas_y: int
var plague_color: Color = Color(0.4, 0.3, 0.2, 1.0)  # Dark brown
# In plague.gd, add a team property
var team: String = "Plague"  # Plague is its own "team"

# Signal for when the plague has reached its lifetime
signal plague_ended(plague)

func _ready() -> void:
	z_index = 3  # Between biomes and remains
	
	# Choose a random texture from available atlas coordinates
	var random_index = randi() % atlas_coords.size()
	atlas_x = atlas_coords[random_index].x
	atlas_y = atlas_coords[random_index].y
	
	# Create sprite
	create_sprite()

func create_sprite() -> void:
	# Remove any existing sprites first
	for child in get_children():
		if child is Sprite2D:
			child.queue_free()
	
	# Create a new sprite
	var sprite_node = Sprite2D.new()
	sprite_node.texture = sprite
	sprite_node.region_enabled = true  # Enable region selection for atlas
	sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)
	
	# Apply color tint
	sprite_node.modulate = plague_color
	
	add_child(sprite_node)
	
	# For debugging
	print("Plague sprite created with atlas coords: ", atlas_x, ",", atlas_y)

# Initialize the plague with position and lifetime
func initialize(grid_pos: Vector2i) -> void:
	position_in_grid = grid_pos
	
	# Set random lifetime between 20-100 iterations
	lifetime = randi() % 81 + 20  # 20 to 100
	
	# Set the global position based on grid position
	global_position = Vector2(grid_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
						  grid_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Make sure sprite is created
	create_sprite()
	
	# For debugging
	print("Plague initialized at position: ", grid_pos, " with lifetime: ", lifetime)

# Process a turn - return true if plague has ended
func process_turn() -> bool:
	lifetime -= 1
	
	# Visual feedback as lifetime decreases (slowly fade out)
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		var current_alpha = max(0.5, float(lifetime) / 100.0)  # Minimum alpha of 0.5
		sprite_node.modulate.a = current_alpha
	
	if lifetime <= 0:
		# Signal that this plague cell has reached the end of its lifetime
		emit_signal("plague_ended", self)
		return true
		
	return false
