extends Node2D
class_name EntityVisionVisualizer

var entity: Entity
var vision_area: Array[Vector2i] = []
var debug_squares: Array[Node2D] = []
var is_visible: bool = false

func _init(parent_entity: Entity) -> void:
    entity = parent_entity

func show_vision_area(vision: Array[Vector2i]) -> void:
    vision_area = vision
    
    # Clear existing debug squares
    for square in debug_squares:
        square.queue_free()
    debug_squares.clear()
    
    # Create new debug squares for each vision cell
    for vision_pos in vision_area:
        var square = Node2D.new()
        square.z_index = -2  # Make sure vision squares appear below movement squares
        
        # Add the square to our vision visualizer
        add_child(square)
        debug_squares.append(square)
        
        # Position the square on the grid
        square.global_position = Vector2(vision_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
                                         vision_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
    
    # Force redraw
    queue_redraw()

func _draw() -> void:
    if not is_visible:
        return
        
    # Get entity's team color but make it more transparent than movement squares
    var color = entity.entity_color
    var transparent_color = Color(color.r, color.g, color.b, 0.15)  # Very transparent for vision
    
    # Draw squares for each vision cell
    for i in range(debug_squares.size()):
        var square_pos = debug_squares[i].global_position - global_position
        var rect = Rect2(square_pos - Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2), 
                        Game.CELL_SIZE)
        draw_rect(rect, transparent_color, true)

func set_visibility(visible: bool) -> void:
    is_visible = visible
    queue_redraw()