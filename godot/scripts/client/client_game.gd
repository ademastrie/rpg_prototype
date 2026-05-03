extends Node2D

@onready var status_label: Label = $StatusLabel

var selected_character: Dictionary = {}


func _ready() -> void:
	set_selected_character(ClientSession.selected_character)


func set_selected_character(character_data: Dictionary) -> void:
	selected_character = character_data
	if selected_character.is_empty():
		status_label.text = "No character selected."
		print("Client game loaded without selected character data.")
		return

	var character_name := str(selected_character.get("name", "Unnamed"))
	var level := int(selected_character.get("level", 1))
	var region_id := str(selected_character.get("region_id", "unknown_region"))
	status_label.text = "Character: %s | Level %s | Region: %s" % [character_name, level, region_id]
	print("Client game loaded character: %s" % selected_character)
