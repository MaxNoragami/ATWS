extends Node2D

class_name RigidBody

@export var sprite: Texture2D
var atlas_x: int = 48  # Default to rigid body coords
var atlas_y: int = 8
var entity_color: Color = Color(1.0, 1.0, 1.0)  # Default color (white)
var team: String = "None"
var position_in_grid: Vector2i

func _ready() -> void:
	z_index = 5
	# Create sprite if it doesn't exist
	if get_child_count() == 0 or not get_child(0) is Sprite2D:
		var sprite_node = Sprite2D.new()
		sprite_node.texture = sprite
		sprite_node.region_enabled = true  # Enable region selection for atlas
		sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)
		
		# Apply color tint
		sprite_node.modulate = entity_color
		
		add_child(sprite_node)

# Initialize the rigid body with custom parameters
func initialize(color: Color, team_name: String) -> void:
	entity_color = color
	team = team_name
	
	# Update the sprite if it already exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = entity_color

# Helper function to update sprite appearance if needed
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