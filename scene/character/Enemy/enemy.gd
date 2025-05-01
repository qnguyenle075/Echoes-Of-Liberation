extends CharacterBody2D

@export var speed := 40
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction := Vector2.ZERO
var change_dir_timer := 0.0
var change_interval := 1.5

var last_direction := Vector2.DOWN

func _ready():
	randomize()
	direction = choose_random_direction()
	last_direction = Vector2.DOWN

func _physics_process(delta):
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		direction = choose_random_direction()
		change_dir_timer = change_interval

	velocity = direction * speed
	move_and_slide()

	update_animation()

func choose_random_direction() -> Vector2:
	var dirs = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	return dirs[randi() % dirs.size()]

func update_animation():
	if direction == Vector2.ZERO:
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x > 0:
				animated_sprite.animation = "Idle_Right"
			else:
				animated_sprite.animation = "Idle_Left"
		else:
			if last_direction.y > 0:
				animated_sprite.animation = "Idle_Down"
			else:
				animated_sprite.animation = "Idle_Up"
	else:
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				animated_sprite.animation = "Run_Right"
				last_direction = Vector2.RIGHT
			else:
				animated_sprite.animation = "Run_Left"
				last_direction = Vector2.LEFT
		else:
			if direction.y > 0:
				animated_sprite.animation = "Run_Down"
				last_direction = Vector2.DOWN
			else:
				animated_sprite.animation = "Run_Up"
				last_direction = Vector2.UP
	animated_sprite.play()

func _on_area_2d_body_entered(body):
	if body.is_in_group("players"):
		if body.has_method("die"):
			body.die()

var is_dead := false

func die():
	# (Giữ nguyên code die của bạn)
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	animated_sprite.play("die")
	await get_tree().create_timer(0.5).timeout
	queue_free()
