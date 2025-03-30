extends Node
class_name EntityMovement

# Reference to the parent entity
var entity: Entity
var possible_moves: Array[Vector2i] = []

# Called when the node enters the scene tree for the first time
func _ready() -> void:
    # Get reference to parent entity
    entity = get_parent() as Entity
    if not entity:
        push_error("EntityMovement must be a child of an Entity node")

# Calculate all possible moves (8 directions, 1 square)
func calculate_possible_moves(grid_size: Vector2i) -> Array[Vector2i]:
    possible_moves.clear()
    
    # Check all 8 directions (horizontal, vertical, diagonal)
    for x in range(-1, 2):
        for y in range(-1, 2):
            # Skip the current position (0,0)
            if x == 0 and y == 0:
                continue
                
            var new_pos = entity.position_in_grid + Vector2i(x, y)
            
            # Ensure new position stays within grid bounds
            if new_pos.x >= 0 and new_pos.x < grid_size.x and new_pos.y >= 0 and new_pos.y < grid_size.y:
                possible_moves.append(new_pos)
    
    return possible_moves

# Move entity randomly but only to valid adjacent cells
func move_randomly(grid_size: Vector2i) -> void:
    # Calculate possible moves
    calculate_possible_moves(grid_size)
    
    # If there are possible moves, choose one randomly
    if possible_moves.size() > 0:
        var random_index = randi() % possible_moves.size()
        var new_position = possible_moves[random_index]
        
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