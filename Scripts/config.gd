extends Control

# Store default values
var default_values = {
	# Entity/Human values
	"lifespan": 100,
	"birth_age": 0,
	"fertility": 0.5,
	"fertility_decrease": 0.17,
	
	# Tank values
	"hunting_cooldown": 0,
	
	# House values
	"capacity": 4,
	
	# UFO values
	"max_presence": 3,
	"max_humans_amount": 5,
	
	# Bomb values
	"countdown": 3,
	"explosion_radius": 1,
	"plague_cells": 7,
	
	# Jet values
	"speed": 2,
	"cooldown_duration": 8
}

# Store max values for validation
var max_values = {
	# Entity/Human values
	"lifespan": 200,
	"birth_age": 50,
	"fertility": 1.0,
	"fertility_decrease": 1.0,
	
	# Tank values
	"hunting_cooldown": 20,
	
	# House values
	"capacity": 10,
	
	# UFO values
	"max_presence": 10,
	"max_humans_amount": 10,
	
	# Bomb values
	"countdown": 10,
	"explosion_radius": 5,
	"plague_cells": 20,
	
	# Jet values
	"speed": 5,
	"cooldown_duration": 20
}

# Current values (initialized to defaults)
var current_values = {
	# Entity/Human values
	"lifespan": default_values["lifespan"],
	"birth_age": default_values["birth_age"],
	"fertility": default_values["fertility"],
	"fertility_decrease": default_values["fertility_decrease"],
	
	# Tank values
	"hunting_cooldown": default_values["hunting_cooldown"],
	
	# House values
	"capacity": default_values["capacity"],
	
	# UFO values
	"max_presence": default_values["max_presence"],
	"max_humans_amount": default_values["max_humans_amount"],
	
	# Bomb values
	"countdown": default_values["countdown"],
	"explosion_radius": default_values["explosion_radius"],
	"plague_cells": default_values["plague_cells"],
	
	# Jet values
	"speed": default_values["speed"],
	"cooldown_duration": default_values["cooldown_duration"]
}

# Reference to the game manager
var game_manager = null

func _ready():
	# Connect Human tab buttons
	var human_tab = $MarginContainerOut/TabContainer/Human
	
	# Connect lifespan undo button
	var lifespan_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Lifespan")
	var lifespan_input = lifespan_container.get_node("ValueLineEdit")
	var lifespan_undo = lifespan_container.get_node("UndoButton")
	lifespan_undo.connect("pressed", _on_lifespan_undo_pressed)
	lifespan_input.connect("text_changed", _on_lifespan_text_changed)
	
	# Connect birth age undo button
	var birth_age_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/BirthAge")
	var birth_age_input = birth_age_container.get_node("ValueLineEdit")
	var birth_age_undo = birth_age_container.get_node("UndoButton")
	birth_age_undo.connect("pressed", _on_birth_age_undo_pressed)
	birth_age_input.connect("text_changed", _on_birth_age_text_changed)
	
	# Connect fertility undo button
	var fertility_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Fertility")
	var fertility_input = fertility_container.get_node("ValueLineEdit")
	var fertility_undo = fertility_container.get_node("UndoButton")
	fertility_undo.connect("pressed", _on_fertility_undo_pressed)
	fertility_input.connect("text_changed", _on_fertility_text_changed)
	
	# Connect fertility decrease undo button
	var fertility_decrease_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/FertilityDecrease")
	var fertility_decrease_input = fertility_decrease_container.get_node("ValueLineEdit")
	var fertility_decrease_undo = fertility_decrease_container.get_node("UndoButton")
	fertility_decrease_undo.connect("pressed", _on_fertility_decrease_undo_pressed)
	fertility_decrease_input.connect("text_changed", _on_fertility_decrease_text_changed)
	
	# Connect Tank tab buttons
	var tank_tab = $MarginContainerOut/TabContainer/Tank
	
	# Connect hunting cooldown undo button
	var hunting_cooldown_container = tank_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/HuntingCooldown")
	var hunting_cooldown_input = hunting_cooldown_container.get_node("ValueLineEdit")
	var hunting_cooldown_undo = hunting_cooldown_container.get_node("UndoButton")
	hunting_cooldown_undo.connect("pressed", _on_hunting_cooldown_undo_pressed)
	hunting_cooldown_input.connect("text_changed", _on_hunting_cooldown_text_changed)
	
	# Connect House tab buttons
	var house_tab = $MarginContainerOut/TabContainer/House
	
	# Connect capacity undo button
	var capacity_container = house_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Capacity")
	var capacity_input = capacity_container.get_node("ValueLineEdit")
	var capacity_undo = capacity_container.get_node("UndoButton")
	capacity_undo.connect("pressed", _on_capacity_undo_pressed)
	capacity_input.connect("text_changed", _on_capacity_text_changed)
	
	# Connect UFO tab buttons
	var ufo_tab = $MarginContainerOut/TabContainer/UFO
	
	# Connect max presence undo button
	var max_presence_container = ufo_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/MaxPresence")
	var max_presence_input = max_presence_container.get_node("ValueLineEdit")
	var max_presence_undo = max_presence_container.get_node("UndoButton")
	max_presence_undo.connect("pressed", _on_max_presence_undo_pressed)
	max_presence_input.connect("text_changed", _on_max_presence_text_changed)

	# Connect max humans amount undo button - update this node name to match the scene
	var max_humans_container = ufo_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/MaxHuman")
	var max_humans_input = max_humans_container.get_node("ValueLineEdit")
	var max_humans_undo = max_humans_container.get_node("UndoButton")
	max_humans_undo.connect("pressed", _on_max_humans_undo_pressed)
	max_humans_input.connect("text_changed", _on_max_humans_text_changed)

	# Connect Bomb tab buttons
	var bomb_tab = $MarginContainerOut/TabContainer/Bomb
	
	# Connect countdown undo button
	var countdown_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Countdown")
	var countdown_input = countdown_container.get_node("ValueLineEdit")
	var countdown_undo = countdown_container.get_node("UndoButton")
	countdown_undo.connect("pressed", _on_countdown_undo_pressed)
	countdown_input.connect("text_changed", _on_countdown_text_changed)
		
	# Connect explosion radius undo button
	var explosion_radius_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/ExplosionRadius")
	var explosion_radius_input = explosion_radius_container.get_node("ValueLineEdit")
	var explosion_radius_undo = explosion_radius_container.get_node("UndoButton")
	explosion_radius_undo.connect("pressed", _on_explosion_radius_undo_pressed)
	explosion_radius_input.connect("text_changed", _on_explosion_radius_text_changed)
		
	# Connect plague cells undo button - update this node name to match the scene
	var plague_cells_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/PlagueSpawnCells")
	var plague_cells_input = plague_cells_container.get_node("ValueLineEdit")
	var plague_cells_undo = plague_cells_container.get_node("UndoButton")
	plague_cells_undo.connect("pressed", _on_plague_cells_undo_pressed)
	plague_cells_input.connect("text_changed", _on_plague_cells_text_changed)


	# Connect Jet tab buttons
	var jet_tab = $MarginContainerOut/TabContainer/Jet

	# Connect speed undo button
	var speed_container = jet_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Speed")
	var speed_input = speed_container.get_node("ValueLineEdit")
	var speed_undo = speed_container.get_node("UndoButton")
	speed_undo.connect("pressed", _on_speed_undo_pressed)
	speed_input.connect("text_changed", _on_speed_text_changed)

	# Skip CooldownDuration if it doesn't exist in the scene
	if jet_tab.has_node("MarginContainer/ScrollContainer/VBoxContainer/CooldownDuration"):
		var cooldown_duration_container = jet_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/CooldownDuration")
		var cooldown_duration_input = cooldown_duration_container.get_node("ValueLineEdit")
		var cooldown_duration_undo = cooldown_duration_container.get_node("UndoButton")
		cooldown_duration_undo.connect("pressed", _on_cooldown_duration_undo_pressed)
		cooldown_duration_input.connect("text_changed", _on_cooldown_duration_text_changed)
	

# --------- Human/Entity handlers ---------

# Lifespan handlers
func _on_lifespan_undo_pressed():
	var human_tab = $MarginContainerOut/TabContainer/Human
	var lifespan_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Lifespan")
	var lifespan_input = lifespan_container.get_node("ValueLineEdit")
	lifespan_input.text = str(default_values["lifespan"])
	current_values["lifespan"] = default_values["lifespan"]

func _on_lifespan_text_changed(new_text):
	var value = validate_int_input(new_text, 0, max_values["lifespan"])
	current_values["lifespan"] = value

# Birth Age handlers
func _on_birth_age_undo_pressed():
	var human_tab = $MarginContainerOut/TabContainer/Human
	var birth_age_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/BirthAge")
	var birth_age_input = birth_age_container.get_node("ValueLineEdit")
	birth_age_input.text = str(default_values["birth_age"])
	current_values["birth_age"] = default_values["birth_age"]

func _on_birth_age_text_changed(new_text):
	var value = validate_int_input(new_text, 0, max_values["birth_age"])
	current_values["birth_age"] = value

# Fertility handlers
func _on_fertility_undo_pressed():
	var human_tab = $MarginContainerOut/TabContainer/Human
	var fertility_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Fertility")
	var fertility_input = fertility_container.get_node("ValueLineEdit")
	fertility_input.text = str(default_values["fertility"])
	current_values["fertility"] = default_values["fertility"]

func _on_fertility_text_changed(new_text):
	var value = validate_float_input(new_text, 0.0, max_values["fertility"])
	current_values["fertility"] = value

# Fertility Decrease handlers
func _on_fertility_decrease_undo_pressed():
	var human_tab = $MarginContainerOut/TabContainer/Human
	var fertility_decrease_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/FertilityDecrease")
	var fertility_decrease_input = fertility_decrease_container.get_node("ValueLineEdit")
	fertility_decrease_input.text = str(default_values["fertility_decrease"])
	current_values["fertility_decrease"] = default_values["fertility_decrease"]

func _on_fertility_decrease_text_changed(new_text):
	var value = validate_float_input(new_text, 0.0, max_values["fertility_decrease"])
	current_values["fertility_decrease"] = value

# --------- Tank handlers ---------

# Hunting Cooldown handlers
func _on_hunting_cooldown_undo_pressed():
	var tank_tab = $MarginContainerOut/TabContainer/Tank
	var hunting_cooldown_container = tank_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/HuntingCooldown")
	var hunting_cooldown_input = hunting_cooldown_container.get_node("ValueLineEdit")
	hunting_cooldown_input.text = str(default_values["hunting_cooldown"])
	current_values["hunting_cooldown"] = default_values["hunting_cooldown"]

func _on_hunting_cooldown_text_changed(new_text):
	var value = validate_int_input(new_text, 0, max_values["hunting_cooldown"])
	current_values["hunting_cooldown"] = value

# --------- House handlers ---------

# Capacity handlers
func _on_capacity_undo_pressed():
	var house_tab = $MarginContainerOut/TabContainer/House
	var capacity_container = house_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Capacity")
	var capacity_input = capacity_container.get_node("ValueLineEdit")
	capacity_input.text = str(default_values["capacity"])
	current_values["capacity"] = default_values["capacity"]

func _on_capacity_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["capacity"])  # Minimum 1 capacity
	current_values["capacity"] = value

# --------- UFO handlers ---------

# Max Presence handlers
func _on_max_presence_undo_pressed():
	var ufo_tab = $MarginContainerOut/TabContainer/UFO
	var max_presence_container = ufo_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/MaxPresence")
	var max_presence_input = max_presence_container.get_node("ValueLineEdit")
	max_presence_input.text = str(default_values["max_presence"])
	current_values["max_presence"] = default_values["max_presence"]

func _on_max_presence_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["max_presence"]) 
	current_values["max_presence"] = value

# Max Humans Amount handlers
func _on_max_humans_undo_pressed():
	var ufo_tab = $MarginContainerOut/TabContainer/UFO
	var max_humans_container = ufo_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/MaxHumans")
	var max_humans_input = max_humans_container.get_node("ValueLineEdit")
	max_humans_input.text = str(default_values["max_humans_amount"])
	current_values["max_humans_amount"] = default_values["max_humans_amount"]

func _on_max_humans_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["max_humans_amount"])
	current_values["max_humans_amount"] = value

# --------- Bomb handlers ---------

# Countdown handlers
func _on_countdown_undo_pressed():
	var bomb_tab = $MarginContainerOut/TabContainer/Bomb
	var countdown_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Countdown")
	var countdown_input = countdown_container.get_node("ValueLineEdit")
	countdown_input.text = str(default_values["countdown"])
	current_values["countdown"] = default_values["countdown"]

func _on_countdown_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["countdown"])
	current_values["countdown"] = value

# Explosion Radius handlers
func _on_explosion_radius_undo_pressed():
	var bomb_tab = $MarginContainerOut/TabContainer/Bomb
	var explosion_radius_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/ExplosionRadius")
	var explosion_radius_input = explosion_radius_container.get_node("ValueLineEdit")
	explosion_radius_input.text = str(default_values["explosion_radius"])
	current_values["explosion_radius"] = default_values["explosion_radius"]

func _on_explosion_radius_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["explosion_radius"])
	current_values["explosion_radius"] = value

# Plague Cells handlers
func _on_plague_cells_undo_pressed():
	var bomb_tab = $MarginContainerOut/TabContainer/Bomb
	var plague_cells_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/PlagueCells")
	var plague_cells_input = plague_cells_container.get_node("ValueLineEdit")
	plague_cells_input.text = str(default_values["plague_cells"])
	current_values["plague_cells"] = default_values["plague_cells"]

func _on_plague_cells_text_changed(new_text):
	var value = validate_int_input(new_text, 0, max_values["plague_cells"])
	current_values["plague_cells"] = value

# --------- Jet handlers ---------

# Speed handlers
func _on_speed_undo_pressed():
	var jet_tab = $MarginContainerOut/TabContainer/Jet
	var speed_container = jet_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Speed")
	var speed_input = speed_container.get_node("ValueLineEdit")
	speed_input.text = str(default_values["speed"])
	current_values["speed"] = default_values["speed"]

func _on_speed_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["speed"])
	current_values["speed"] = value

# Cooldown Duration handlers
func _on_cooldown_duration_undo_pressed():
	var jet_tab = $MarginContainerOut/TabContainer/Jet
	var cooldown_duration_container = jet_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/CooldownDuration")
	var cooldown_duration_input = cooldown_duration_container.get_node("ValueLineEdit")
	cooldown_duration_input.text = str(default_values["cooldown_duration"])
	current_values["cooldown_duration"] = default_values["cooldown_duration"]

func _on_cooldown_duration_text_changed(new_text):
	var value = validate_int_input(new_text, 1, max_values["cooldown_duration"])
	current_values["cooldown_duration"] = value

# Validate integer input
func validate_int_input(text, min_value, max_value):
	if text.is_empty():
		return min_value
	
	# Try to convert to integer
	var value = text.to_int()
	
	# Clamp between min and max
	value = clamp(value, min_value, max_value)
	
	return value

# Validate float input
func validate_float_input(text, min_value, max_value):
	if text.is_empty():
		return min_value
	
	# Try to convert to float
	var value = text.to_float()
	
	# Clamp between min and max
	value = clamp(value, min_value, max_value)
	
	return value

# Apply the configurations when the window is closed
func apply_configuration():
	# Validate and clamp all values
	validate_all_values()
	
	# Update the LineEdit text to show clamped values
	update_input_fields()

# Validate all values against min/max constraints
func validate_all_values():
	# Entity/Human values
	current_values["lifespan"] = clamp(current_values["lifespan"], 0, max_values["lifespan"])
	current_values["birth_age"] = clamp(current_values["birth_age"], 0, max_values["birth_age"])
	current_values["fertility"] = clamp(current_values["fertility"], 0.0, max_values["fertility"])
	current_values["fertility_decrease"] = clamp(current_values["fertility_decrease"], 0.0, max_values["fertility_decrease"])
	
	# Tank values
	current_values["hunting_cooldown"] = clamp(current_values["hunting_cooldown"], 0, max_values["hunting_cooldown"])
	
	# House values
	current_values["capacity"] = clamp(current_values["capacity"], 1, max_values["capacity"])
	
	# UFO values
	current_values["max_presence"] = clamp(current_values["max_presence"], 1, max_values["max_presence"])
	current_values["max_humans_amount"] = clamp(current_values["max_humans_amount"], 1, max_values["max_humans_amount"])
	
	# Bomb values
	current_values["countdown"] = clamp(current_values["countdown"], 1, max_values["countdown"])
	current_values["explosion_radius"] = clamp(current_values["explosion_radius"], 1, max_values["explosion_radius"])
	current_values["plague_cells"] = clamp(current_values["plague_cells"], 0, max_values["plague_cells"])
	
	# Jet values
	current_values["speed"] = clamp(current_values["speed"], 1, max_values["speed"])
	current_values["cooldown_duration"] = clamp(current_values["cooldown_duration"], 1, max_values["cooldown_duration"])

# Update all input fields to match current values
func update_input_fields():
	# Update Human/Entity fields
	var human_tab = $MarginContainerOut/TabContainer/Human
	
	# Update lifespan input
	var lifespan_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Lifespan")
	var lifespan_input = lifespan_container.get_node("ValueLineEdit")
	lifespan_input.text = str(current_values["lifespan"])
	
	# Update birth age input
	var birth_age_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/BirthAge")
	var birth_age_input = birth_age_container.get_node("ValueLineEdit")
	birth_age_input.text = str(current_values["birth_age"])
	
	# Update fertility input
	var fertility_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Fertility")
	var fertility_input = fertility_container.get_node("ValueLineEdit")
	fertility_input.text = str(current_values["fertility"])
	
	# Update fertility decrease input
	var fertility_decrease_container = human_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/FertilityDecrease")
	var fertility_decrease_input = fertility_decrease_container.get_node("ValueLineEdit")
	fertility_decrease_input.text = str(current_values["fertility_decrease"])
	
	# Update Tank fields
	var tank_tab = $MarginContainerOut/TabContainer/Tank
	
	# Update hunting cooldown input
	var hunting_cooldown_container = tank_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/HuntingCooldown")
	var hunting_cooldown_input = hunting_cooldown_container.get_node("ValueLineEdit")
	hunting_cooldown_input.text = str(current_values["hunting_cooldown"])
	
	# Update House fields
	var house_tab = $MarginContainerOut/TabContainer/House
	
	# Update capacity input
	var capacity_container = house_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Capacity")
	var capacity_input = capacity_container.get_node("ValueLineEdit")
	capacity_input.text = str(current_values["capacity"])
	
	
	# Update UFO fields
	var ufo_tab = $MarginContainerOut/TabContainer/UFO
		
	# Update max presence input
	var max_presence_container = ufo_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/MaxPresence")
	var max_presence_input = max_presence_container.get_node("ValueLineEdit")
	max_presence_input.text = str(current_values["max_presence"])
		
	# Update max humans amount input - Fix the node name
	var max_humans_container = ufo_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/MaxHuman")
	var max_humans_input = max_humans_container.get_node("ValueLineEdit")
	max_humans_input.text = str(current_values["max_humans_amount"])
		
	# Update Bomb fields
	var bomb_tab = $MarginContainerOut/TabContainer/Bomb
		
	# Update countdown input
	var countdown_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Countdown")
	var countdown_input = countdown_container.get_node("ValueLineEdit")
	countdown_input.text = str(current_values["countdown"])
		
	# Update explosion radius input
	var explosion_radius_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/ExplosionRadius")
	var explosion_radius_input = explosion_radius_container.get_node("ValueLineEdit")
	explosion_radius_input.text = str(current_values["explosion_radius"])
		
	# Update plague cells input - Fix the node name
	var plague_cells_container = bomb_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/PlagueSpawnCells")
	var plague_cells_input = plague_cells_container.get_node("ValueLineEdit")
	plague_cells_input.text = str(current_values["plague_cells"])
	
	# Update Jet fields
	var jet_tab = $MarginContainerOut/TabContainer/Jet

	# Update speed input
	var speed_container = jet_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/Speed")
	var speed_input = speed_container.get_node("ValueLineEdit")
	speed_input.text = str(current_values["speed"])

	# Skip CooldownDuration if it doesn't exist
	if jet_tab.has_node("MarginContainer/ScrollContainer/VBoxContainer/CooldownDuration"):
		var cooldown_duration_container = jet_tab.get_node("MarginContainer/ScrollContainer/VBoxContainer/CooldownDuration")
		var cooldown_duration_input = cooldown_duration_container.get_node("ValueLineEdit")
		cooldown_duration_input.text = str(current_values["cooldown_duration"])

# Get the current configuration for entity creation
func get_entity_config():
	return {
		"lifespan": current_values["lifespan"],
		"birth_age": current_values["birth_age"],
		"fertility": current_values["fertility"],
		"fertility_decrease": current_values["fertility_decrease"]
	}

# Get the current configuration for tank creation
func get_tank_config():
	return {
		"hunting_cooldown": current_values["hunting_cooldown"]
	}

# Get the current configuration for house creation
func get_house_config():
	return {
		"capacity": current_values["capacity"]
	}

# Get the current configuration for UFO creation
func get_ufo_config():
	return {
		"max_presence": current_values["max_presence"],
		"max_humans_amount": current_values["max_humans_amount"]
	}

# Get the current configuration for bomb creation
func get_bomb_config():
	return {
		"countdown": current_values["countdown"],
		"explosion_radius": current_values["explosion_radius"],
		"plague_cells": current_values["plague_cells"]
	}

# Get the current configuration for jet creation
func get_jet_config():
	return {
		"speed": current_values["speed"],
		"cooldown_duration": current_values["cooldown_duration"]
	}
