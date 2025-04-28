extends Node2D

func _ready():
	$AnimatedSprite2D.play("boom")
	$Timer.timeout.connect(func(): queue_free())
