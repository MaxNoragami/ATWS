extends Node2D

class_name House

@export var sprite: Texture2D
var atlas_x: int = 0  # House texture coordinates in atlas
var atlas_y: int = 20
var entity_color: Color = Color(1.0, 1.0, 1.0)  # Default color (white)
var team: String = "None"
var position_in_grid: Vector2i

# House properties
var max_capacity: int = 4
var entities_inside: Array[Entity] = []
var entrance_positions: Array[Vector2i] = []

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
	
	# Calculate entrance positions (up, down, left, right)
	update_entrance_positions()

# Initialize the house with custom parameters
func initialize(color: Color, team_name: String) -> void:
	entity_color = color
	team = team_name
	
	# Update the sprite if it already exists
	if get_child_count() > 0 and get_child(0) is Sprite2D:
		get_child(0).modulate = entity_color
	
	# Calculate entrance positions
	update_entrance_positions()

# Calculate entrance positions around the house (up, down, left, right)
func update_entrance_positions() -> void:
	entrance_positions.clear()
	
	# Up, Right, Down, Left (no diagonals)
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0)   # Left
	]
	
	for dir in directions:
		var entrance_pos = position_in_grid + dir
		entrance_positions.append(entrance_pos)

# Check if an entity can enter the house
func can_entity_enter(entity: Entity, grid_size: Vector2i, occupied_positions: Dictionary) -> bool:
	# Check if house is at capacity
	if entities_inside.size() >= max_capacity:
		return false
	
	# Check if entity is on a valid entrance position
	if not is_at_valid_entrance(entity.position_in_grid, grid_size, occupied_positions):
		return false
	
	# Check if entity is from the same team
	if entity.team != team:
		return false
		
	# Check if entity has a house entry cooldown
	if entity.has_meta("house_entry_cooldown"):
		return false
	
	return true

# Check if a position is a valid entrance (not blocked by rigid body or border)
func is_at_valid_entrance(pos: Vector2i, grid_size: Vector2i, occupied_positions: Dictionary) -> bool:
	for entrance_pos in entrance_positions:
		if pos == entrance_pos:
			# Check if entrance is within grid boundaries
			if entrance_pos.x < 0 or entrance_pos.x >= grid_size.x or entrance_pos.y < 0 or entrance_pos.y >= grid_size.y:
				continue
			
			# Check if entrance is blocked by a rigid body
			var pos_string = str(entrance_pos.x) + "," + str(entrance_pos.y)
			if occupied_positions.has(pos_string):
				var occupier = occupied_positions[pos_string]
				if occupier is RigidBody or occupier is House:
					continue
			
			return true
	
	return false

# Try to add an entity to the house
func try_add_entity(entity: Entity) -> bool:
	if entities_inside.size() >= max_capacity:
		return false
	
	entities_inside.append(entity)
	return true

# Try to remove entity from house at a specific entrance
func try_remove_entity_at_entrance(entrance_index: int, grid_size: Vector2i, occupied_positions: Dictionary) -> Entity:
	if entities_inside.size() == 0:
		return null
	
	if entrance_index < 0 or entrance_index >= entrance_positions.size():
		return null
	
	var entrance_pos = entrance_positions[entrance_index]
	
	# Check if entrance is within grid boundaries
	if entrance_pos.x < 0 or entrance_pos.x >= grid_size.x or entrance_pos.y < 0 or entrance_pos.y >= grid_size.y:
		return null
	
	# Check if entrance is blocked
	var pos_string = str(entrance_pos.x) + "," + str(entrance_pos.y)
	if occupied_positions.has(pos_string):
		return null
	
	# Remove the entity from the house
	var entity = entities_inside.pop_front()
	
	return entity

# Try to remove any entity from the house at any valid entrance
func try_remove_any_entity(grid_size: Vector2i, occupied_positions: Dictionary) -> Array:
	if entities_inside.size() == 0:
		return [null, -1]  # No entities to remove
	
	# Check all entrances in random order
	var entrance_indices = [0, 1, 2, 3]
	entrance_indices.shuffle()
	
	for i in entrance_indices:
		var entrance_pos = entrance_positions[i]
		
		# Check if entrance is within grid boundaries
		if entrance_pos.x < 0 or entrance_pos.x >= grid_size.x or entrance_pos.y < 0 or entrance_pos.y >= grid_size.y:
			continue
		
		# Check if entrance is blocked by ANYTHING (entity, rigid body, or another house)
		var pos_string = str(entrance_pos.x) + "," + str(entrance_pos.y)
		if occupied_positions.has(pos_string):
			continue
		
		# Make sure entrance position is exactly one of the four cardinal directions
		if not (entrance_pos == position_in_grid + Vector2i(0, -1) or  # Up
				entrance_pos == position_in_grid + Vector2i(1, 0) or   # Right
				entrance_pos == position_in_grid + Vector2i(0, 1) or   # Down
				entrance_pos == position_in_grid + Vector2i(-1, 0)):   # Left
			push_error("Invalid entrance position: " + str(entrance_pos))
			continue
		
		# Remove the entity from the house
		var entity = entities_inside.pop_front()
		return [entity, i]  # Return entity and entrance index
	
	return [null, -1]  # No valid entrances

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

# Check if there are any enemy tanks nearby
func has_enemy_tanks_nearby(grid_size: Vector2i, occupied_positions: Dictionary, scan_radius: int = 3) -> bool:
	# Create a scan area around the house
	for x in range(-scan_radius, scan_radius + 1):
		for y in range(-scan_radius, scan_radius + 1):
			var check_pos = position_in_grid + Vector2i(x, y)
			
			# Skip if outside grid
			if check_pos.x < 0 or check_pos.x >= grid_size.x or check_pos.y < 0 or check_pos.y >= grid_size.y:
				continue
				
			# Check if there's a tank at this position
			var pos_string = str(check_pos.x) + "," + str(check_pos.y)
			if occupied_positions.has(pos_string):
				var object = occupied_positions[pos_string]
				
				# If it's an enemy tank, return true
				if object is Tank and object.team != team and not object.is_dead:
					return true
	
	# No enemy tanks found
	return false