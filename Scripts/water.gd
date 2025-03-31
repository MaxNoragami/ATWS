extends Node2D

class_name WaterBiome

@export var sprite: Texture2D
var position_in_grid: Vector2i
var atlas_x: int = 1  # Atlas coordinates for water texture - adjust for your sprite atlas
var atlas_y: int = 17
var water_color: Color = Color(0.3, 0.5, 0.9, 0.8)  # Blue with some transparency - fixed color regardless of team

func _ready() -> void:
	# Set the node's z-index
	z_index = 2
	
	# Create a basic sprite
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
	sprite_node.modulate = water_color
	
	add_child(sprite_node)
	
	# For debugging
	print("Water sprite created with color: ", water_color)

# Initialize the biome with position
func initialize(grid_pos: Vector2i) -> void:
	position_in_grid = grid_pos
	
	# Set the global position based on grid position
	global_position = Vector2(grid_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
						  grid_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Make sure sprite is created
	create_sprite()
	
	# For debugging
	print("Water biome initialized at position: ", grid_pos)

# Helper function to set opacity (useful for preview)
func set_opacity(opacity: float) -> void:
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		var sprite_node = get_child(0) as Sprite2D
		var current_color = sprite_node.modulate
		sprite_node.modulate = Color(current_color.r, current_color.g, current_color.b, opacity)
