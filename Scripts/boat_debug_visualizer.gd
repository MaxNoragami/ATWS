extends Node2D
class_name BoatDebugVisualizer

var boat: Boat
var possible_moves: Array[Vector2i] = []
var debug_squares: Array[Node2D] = []
var is_visible: bool = false

func _init(parent_boat: Boat) -> void:
	boat = parent_boat

func show_possible_moves(moves: Array[Vector2i]) -> void:
	possible_moves = moves
	
	# Clear existing debug squares
	for square in debug_squares:
		square.queue_free()
	debug_squares.clear()
	
	# Create new debug squares for each possible move
	for move_pos in possible_moves:
		var square = Node2D.new()
		square.z_index = -1  # Make sure squares appear below entities
		
		# Add the square to our debug visualizer
		add_child(square)
		debug_squares.append(square)
		
		# Position the square on the grid
		square.global_position = Vector2(move_pos.x * Game.CELL_SIZE.x + Game.CELL_SIZE.x / 2, 
										 move_pos.y * Game.CELL_SIZE.y + Game.CELL_SIZE.y / 2)

func _draw() -> void:
	if not is_visible:
		return
		
	# Get boat's team color
	var color = boat.entity_color
	var transparent_color = Color(color.r, color.g, color.b, 0.3)
	
	# Draw squares for each possible move
	for i in range(debug_squares.size()):
		var square_pos = debug_squares[i].global_position - global_position
		var rect = Rect2(square_pos - Vector2(Game.CELL_SIZE.x / 2, Game.CELL_SIZE.y / 2), 
						Game.CELL_SIZE)
		draw_rect(rect, transparent_color, true)

func set_visibility(visible: bool) -> void:
	is_visible = visible
	queue_redraw()
