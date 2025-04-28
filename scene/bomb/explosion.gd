extends Area2D

@onready var anim = $AnimatedSprite2D
@onready var timer = $Timer

func play_animation(name: String):
	anim.play(name)

func _ready():
	timer.timeout.connect(_on_timeout)

func _on_timeout():
	queue_free()
