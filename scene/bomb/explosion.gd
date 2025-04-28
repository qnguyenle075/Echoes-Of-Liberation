extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var timer = $Timer

func play_animation(name: String):
	anim.play(name)

func _ready():
	timer.timeout.connect(_on_timeout)
	connect("body_entered", _on_body_entered)

func _on_timeout():
	queue_free()

func _on_body_entered(body):
	if body is CharacterBody2D:
		body.die()
