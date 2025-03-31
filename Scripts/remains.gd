extends Node2D

class_name Remains

@export var sprite: Texture2D
var atlas_x: int = 19  # Fixed remains texture coords
var atlas_y: int = 1
var entity_color: Color = Color(1.0, 1.0, 1.0)  # Default color (white)
var team: String = "None"
var position_in_grid: Vector2i
var lifetime: int = 1  # Disappears after 1 generation

func _ready() -> void:
	# Create sprite if it doesn't exist
	if get_child_count() == 0 or not get_child(0) is Sprite2D:
		var sprite_node = Sprite2D.new()
		sprite_node.texture = sprite
		sprite_node.region_enabled = true  # Enable region selection for atlas
		sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)
		
		# Apply color tint
		sprite_node.modulate = entity_color
		
		add_child(sprite_node)

# Initialize the remains with custom parameters
func initialize(color: Color, team_name: String) -> void:
	entity_color = color
	team = team_name
	
	# Update the sprite if it already exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = entity_color

# Reduce lifetime - returns true if the remains should be removed
func age() -> bool:
	lifetime -= 1
	return lifetime <= 0
