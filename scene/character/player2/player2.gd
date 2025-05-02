extends CharacterBody2D


const SPEED = 60.0
@export var input_prefix : String = "p2"
@onready var BombScene = preload("res://scene/bomb/bomb.tscn")
@onready var animated_sprite = $AnimatedSprite2D
var last_direction: String = "south"  # Hướng mặc định ban đầu


var bomb_exists := false


func _physics_process(delta: float) -> void:
	var input_vector = Vector2(
		Input.get_action_strength("right_" + input_prefix) - Input.get_action_strength("left_" + input_prefix),
		Input.get_action_strength("down_"  + input_prefix) - Input.get_action_strength("up_" + input_prefix)
	).normalized()
	if Input.is_action_just_pressed("boom_" + input_prefix) and not bomb_exists:
		place_bomb()
	velocity = input_vector * SPEED
	move_and_slide()

	update_animation(input_vector)
func place_bomb():
	# Làm tròn vị trí đặt bomb để khớp ô lưới (nếu cần)
	var tile_size = 16
	var bomb_position = Vector2(
	int(global_position.x / tile_size) * tile_size + tile_size / 2,
	int(global_position.y / tile_size) * tile_size + tile_size / 2
	)
	var bomb = BombScene.instantiate()
	get_parent().add_child(bomb)
	bomb.global_position = bomb_position
	bomb_exists = true

	# Lắng nghe khi bomb nổ xong (dùng signal)
	bomb.connect("bomb_exploded", Callable(self, "_on_bomb_exploded"))

func _on_bomb_exploded():
	bomb_exists = false

func update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		# Đứng yên: idle theo hướng cuối cùng
		animated_sprite.animation = "idle_" + last_direction
	else:
		# Di chuyển: run_* theo hướng hiện tại và cập nhật last_direction
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				animated_sprite.animation = "run_east"
				last_direction = "east"
			else:
				animated_sprite.animation = "run_west"
				last_direction = "west"
		else:
			if direction.y > 0:
				animated_sprite.animation = "run_south"
				last_direction = "south"
			else:
				animated_sprite.animation = "run_north"
				last_direction = "north"

	animated_sprite.play()
	
var is_dead := false

func die():
	if is_dead:
		return
	is_dead = true

	velocity = Vector2.ZERO
	set_physics_process(false)
	animated_sprite.play("die")

	# Force chờ khoảng 0.5 giây rồi biến mất
	await Music.play_sfx_and_wait("res://assets/Sound/game_over.wav")
	queue_free()
	get_tree().change_scene_to_file("res://scene/gameovermenu/player1win.tscn")
