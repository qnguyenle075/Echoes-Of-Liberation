extends Area2D

@onready var anim = $AnimatedSprite2D

func play_animation(name: String):
	anim.animation = name
	anim.play()
	await anim.animation_finished
	queue_free()
