extends Node

# Here we store our constant values
const GRID_SIZE : Vector2 = Vector2(800, 480)
const CELL_SIZE : Vector2 = Vector2(16, 16)

# How many cells the grid has both horizontally and vertically
const CELLS_AMOUNT : Vector2 = Vector2(GRID_SIZE.x / CELL_SIZE.x, GRID_SIZE.y / CELL_SIZE.y)
