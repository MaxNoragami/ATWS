extends Node2D

# Entity script to move randomly per iteration
class_name Entity

@export var sprite: Texture2D
@export var atlas_x: int = 9
@export var atlas_y: int = 20
var entity_color: Color = Color(1.0, 0.5, 0.5)  # Default color (light red)
var team: String = "None"

var position_in_grid: Vector2i

func _init(color: Color = Color(1.0, 0.5, 0.5), team_name: String = "None") -> void:
    entity_color = color
    team = team_name

func _ready() -> void:
    var sprite_node = Sprite2D.new()
    sprite_node.texture = sprite
    sprite_node.region_enabled = true  # Enable region selection for atlas
    sprite_node.region_rect = Rect2(atlas_x * 16, atlas_y * 16, 16, 16)  # Select tile (9,20)
    
    # Apply color tint instead of shader
    sprite_node.modulate = entity_color
    
    add_child(sprite_node)

func move_randomly(grid_size: Vector2i) -> void:
    # Random movement in the grid
    var direction = Vector2i(randi_range(-1, 1), randi_range(-1, 1))
    var new_position = position_in_grid + direction
    
    # Ensure new position stays within grid bounds
    new_position.x = clamp(new_position.x, 0, grid_size.x - 1)
    new_position.y = clamp(new_position.y, 0, grid_size.y - 1)
    
    position_in_grid = new_position
    global_position = position_in_grid * 16 as Vector2 + Vector2(8, 8)  # Convert grid position to world position