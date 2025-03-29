extends Node2D

# Entity script
class_name Entity

@export var sprite: Texture2D
@export var atlas_x: int = 9
@export var atlas_y: int = 20
var entity_color: Color = Color(1.0, 0.5, 0.5)  # Default color (light red)
var team: String = "None"

var position_in_grid: Vector2i
var movement: EntityMovement

func _init(color: Color = Color(1.0, 0.5, 0.5), team_name: String = "None") -> void:
    entity_color = color
    team = team_name

func _ready() -> void:
    # Create sprite
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

# Delegate to movement component
func move_randomly(grid_size: Vector2i) -> void:
    movement.move_randomly(grid_size)

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