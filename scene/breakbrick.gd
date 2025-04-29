extends Node2D

func _ready():
	var current_map = get_tree().get_current_scene()
	if current_map.is_in_group("map1"):
		$AnimatedSprite2D.play("boom1")
	elif current_map.is_in_group("map2"):
		$AnimatedSprite2D.play("boom2")
	else:
		$AnimatedSprite2D.play("boom1")
	$Timer.timeout.connect(func(): queue_free())
