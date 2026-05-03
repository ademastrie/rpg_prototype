extends Node2D

var selected_character: Dictionary = {}


func set_selected_character(character_data: Dictionary) -> void:
	selected_character = character_data
	print("Selected character stored: %s" % selected_character)
