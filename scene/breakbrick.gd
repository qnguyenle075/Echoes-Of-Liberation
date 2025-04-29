extends Node2D

func _ready():
	var current_map = get_tree().get_current_scene()
	if current_map.is_in_group("map1"):
		$AnimatedSprite2D.play("boom1")
	elif current_map.is_in_group("map2"):
		$AnimatedSprite2D.play("boom2")
	elif current_map.is_in_group("map3"):
		$AnimatedSprite2D.play("boom3")
	elif current_map.is_in_group("map4"):
		$AnimatedSprite2D.play("boom4")
	elif current_map.is_in_group("map5"):
		$AnimatedSprite2D.play("boom2")
	else:
		$AnimatedSprite2D.play("boom1")
	$Timer.timeout.connect(func(): queue_free())
