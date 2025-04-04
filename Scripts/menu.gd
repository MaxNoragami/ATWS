extends Control

signal play_pressed
signal credits_pressed

# Reference to the credits screen will be set from the game_loop.gd
var credits_screen: Control = null

func _ready():
    # Connect button signals
    $OutMarginContainer/VBoxContent/MarginButtons/VBoxButtons/Play.connect("pressed", _on_play_pressed)
    $OutMarginContainer/VBoxContent/MarginButtons/VBoxButtons/Credits.connect("pressed", _on_credits_pressed)

func _on_play_pressed():
    emit_signal("play_pressed")
    visible = false

func _on_credits_pressed():
    emit_signal("credits_pressed")
    
    # Show the credits screen if reference is set
    if credits_screen:
        credits_screen.visible = true
        visible = false  # Hide menu while showing credits
    else:
        print("Credits screen reference not set!")

func show_menu():
    visible = true