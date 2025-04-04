extends Node2D
class_name TankVisionVisualizer

var tank: Tank
var vision_area: Array[Vector2i] = []
var kill_zone: Array[Vector2i] = []
var debug_squares: Array[Node2D] = []
var kill_squares: Array[Node2D] = []
var is_visible: bool = false

func _init(parent_tank: Tank) -> void:
	tank = parent_tank

# Show both vision area and kill zone
func show_vision_and_kill_area(vision: Array[Vector2i], kill: Array[Vector2i], grid_size: Vector2i) -> void:
	vision_area = vision
	kill_zone = kill
	
	# Clear existing debug squares
	for square in debug_squares:
		square.queue_free()
	debug_squares.clear()
	
	for square in kill_squares:
		square.queue_free()
	kill_squares.clear()
	
	# Create new debug squares for each vision cell
	for vision_pos in vision_area:
		# Skip if outside grid boundaries
		if vision_pos.x < 0 or vision_pos.x >= grid_size.x or vision_pos.y < 0 or vision_pos.y >= grid_size.y:
			continue
			
		# Skip if this position is also in the kill zone (we'll draw it differently)
		var in_kill_zone = false
		for kill_pos in kill_zone:
			if vision_pos == kill_pos:
				in_kill_zone = true
				break
		
		if in_kill_zone:
			continue
			
		var square = Node2D.new()
		square.z_index = -1  # Make sure squares appear below entities
		
		# Add the square to debug visualizer
		add_child(square)
		debug_squares.append(square)
		
		# Position the square on the grid
		square.global_position = Vector2(vision_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
										 vision_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Create new squares for kill zone (will be drawn with higher opacity)
	for kill_pos in kill_zone:
		# Skip if outside grid boundaries
		if kill_pos.x < 0 or kill_pos.x >= grid_size.x or kill_pos.y < 0 or kill_pos.y >= grid_size.y:
			continue
			
		var square = Node2D.new()
		square.z_index = -1  # Make sure squares appear below entities
		
		# Add the square to kill visualizer
		add_child(square)
		kill_squares.append(square)
		
		# Position the square on the grid
		square.global_position = Vector2(kill_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
										 kill_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)
	
	# Force a redraw to update the visualization
	queue_redraw()

# Legacy method for backward compatibility
func show_vision_area(area: Array[Vector2i], grid_size: Vector2i) -> void:
	show_vision_and_kill_area(area, [], grid_size)

func _draw() -> void:
	if not is_visible:
		return
		
	# Get tank's team color
	var color = tank.entity_color
	
	# Draw squares for vision area (low opacity)
	var transparent_color = Color(color.r, color.g, color.b, 0.2)  # More transparent for vision
	for i in range(debug_squares.size()):
		var square_pos = debug_squares[i].global_position - global_position
		var rect = Rect2(square_pos - Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2), 
						Game.CELL_SIZE)
		draw_rect(rect, transparent_color, true)
	
	# Draw squares for kill zone (higher opacity and slight red tint)
	var kill_color = Color(
		min(color.r + 0.3, 1.0), 
		color.g * 0.7, 
		color.b * 0.7, 
		0.5)  # More opaque for kill zone
	
	for i in range(kill_squares.size()):
		var square_pos = kill_squares[i].global_position - global_position
		var rect = Rect2(square_pos - Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2), 
						Game.CELL_SIZE)
		draw_rect(rect, kill_color, true)

func set_visibility(visible: bool) -> void:
	is_visible = visible
	queue_redraw()
