extends Control

signal play_pressed
signal credits_pressed

func _ready():
    # Connect button signals
    $OutMarginContainer/VBoxContent/MarginButtons/VBoxButtons/Play.connect("pressed", _on_play_pressed)
    $OutMarginContainer/VBoxContent/MarginButtons/VBoxButtons/Credits.connect("pressed", _on_credits_pressed)

func _on_play_pressed():
    emit_signal("play_pressed")
    visible = false

func _on_credits_pressed():
    emit_signal("credits_pressed")
    # For now just print credits - you can implement a proper credits screen later
    print("Credits: Your name and contributors")

func show_menu():
    visible = true