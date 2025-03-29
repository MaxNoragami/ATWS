# human.gd
extends Entity
class_name Human

func _init(color: Color = Color(1.0, 1.0, 0.8), team_name: String = "None") -> void:
    super._init(color, team_name)
    # Human-specific initialization
    
func _ready() -> void:
    super._ready()
    # Override default atlas coordinates for human appearance
    update_sprite(0, 15)  # Example: different sprite coordinates for human
    
    # Add human-specific behaviors
    # For example, humans might move differently
    
# Override movement or add new methods specific to humans
func move_special() -> void:
    # Human-specific movement logic
    pass