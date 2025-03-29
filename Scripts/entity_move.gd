extends Node
class_name EntityMovement

# Reference to the parent entity
var entity: Entity

# Called when the node enters the scene tree for the first time
func _ready() -> void:
    # Get reference to parent entity
    entity = get_parent() as Entity
    if not entity:
        push_error("EntityMovement must be a child of an Entity node")

# Move entity randomly in the grid
func move_randomly(grid_size: Vector2i) -> void:
    # Random movement in the grid
    var direction = Vector2i(randi_range(-1, 1), randi_range(-1, 1))
    var new_position = entity.position_in_grid + direction
    
    # Ensure new position stays within grid bounds
    new_position.x = clamp(new_position.x, 0, grid_size.x - 1)
    new_position.y = clamp(new_position.y, 0, grid_size.y - 1)
    
    # Update entity's grid position
    entity.position_in_grid = new_position
    
    # Update entity's global position based on grid position
    update_position()

# Function to update the entity's global position based on its grid position
func update_position() -> void:
    # Convert Vector2i to Vector2 for multiplication
    var grid_pos_float = Vector2(entity.position_in_grid.x, entity.position_in_grid.y)
    entity.global_position = grid_pos_float * Game.CELL_SIZE + Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2)

# Move to a specific grid position
func move_to_grid_position(grid_pos: Vector2i, grid_size: Vector2i) -> void:
    # Ensure position stays within grid bounds
    var new_position = grid_pos
    new_position.x = clamp(new_position.x, 0, grid_size.x - 1)
    new_position.y = clamp(new_position.y, 0, grid_size.y - 1)
    
    # Update entity's grid position
    entity.position_in_grid = new_position
    
    # Update entity's global position
    update_position()