extends Node

var access_token := ""
var current_user: Dictionary = {}
var selected_character: Dictionary = {}


func clear() -> void:
	access_token = ""
	current_user = {}
	selected_character = {}
