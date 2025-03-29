extends Node2D


func _draw() -> void:
    # Drawing the background
    draw_rect(Rect2(0, 0, Game.GRID_SIZE.x, Game.GRID_SIZE.y), Color("F2F2F0"))

    # Drawing the vertical lines
    for i in Game.CELLS_AMOUNT.x:
        var from := Vector2(i * Game.CELL_SIZE.x, 0) # x = 0, 32, 64, 96, ...
        var to := Vector2(from.x, Game.GRID_SIZE.y)
        draw_line(from, to, Color(030303))

    # Drawing the horizontal lines
    for i in Game.CELLS_AMOUNT.y:
        var from := Vector2(0, i * Game.CELL_SIZE.y) # x = 0, 32, 64, 96, ...
        var to := Vector2(Game.GRID_SIZE.x, from.y)
        draw_line(from, to, Color(030303))