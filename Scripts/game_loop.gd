extends Node2D

@export var entity_scene: PackedScene

var entities: Array[Entity] = []
var grid_size = Vector2i(16, 16)

func _ready() -> void:
    for i in range(5):  # Spawn 5 random entities
        var color = Color(randf(), randf(), randf())  # Generate a random color
        var entity = entity_scene.instantiate() as Entity
        entity._init(color)  # Pass color to constructor
        entity.position_in_grid = Vector2i(randi_range(0, grid_size.x - 1), randi_range(0, grid_size.y - 1))
        entity.global_position = entity.position_in_grid * 16 as Vector2 + Vector2(8, 8)
        add_child(entity)
        entities.append(entity)

func _process(delta: float) -> void:
    pass

func _input(event) -> void:
    if event.is_action_pressed("next_iteration"):
        for entity in entities:
            entity.move_randomly(grid_size)
    if event.is_action_pressed("switch_team"):
        pass
    

