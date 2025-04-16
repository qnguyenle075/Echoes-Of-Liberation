extends Node


# Called when the node enters the scene tree for the first time.


func _on_playagain_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/map.tscn")
	


func _on_exit_pressed() -> void:
	get_tree().quit()
