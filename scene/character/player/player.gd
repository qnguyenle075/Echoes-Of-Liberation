extends CharacterBody2D

# --- TÍN HIỆU CHO ENEMY BIẾT KHI ĐẶT BOM ---
signal planting_bomb_started(position: Vector2) # Phát ra khi bắt đầu đặt bom, kèm vị trí
signal planting_bomb_finished             # Phát ra khi hành động đặt bom hoàn tất

const SPEED = 100.0
@export var input_prefix : String = "p1"
@onready var BombScene = preload("res://scene/bomb/bomb.tscn") # Đảm bảo đường dẫn đúng
@onready var animated_sprite = $AnimatedSprite2D
var last_direction: String = "south"  # Hướng mặc định ban đầu

var bomb_exists := false
var is_dead := false # Thêm biến này lên đầu cho gọn

func _physics_process(delta: float) -> void:
	if is_dead: # Nếu chết thì không làm gì cả
		return

	var input_vector = Vector2(
		Input.get_action_strength("right_" + input_prefix) - Input.get_action_strength("left_" + input_prefix),
		Input.get_action_strength("down_"  + input_prefix) - Input.get_action_strength("up_" + input_prefix)
	).normalized()

	# --- XỬ LÝ ĐẶT BOM ---
	# Kiểm tra input và xem có bom nào đang tồn tại không
	if Input.is_action_just_pressed("boom_" + input_prefix) and not bomb_exists:
		place_bomb() # Gọi hàm đặt bom

	# --- DI CHUYỂN ---
	velocity = input_vector * SPEED
	move_and_slide()

	# --- ANIMATION ---
	update_animation(input_vector)

func place_bomb():
	# 1. >>> PHÁT TÍN HIỆU: BẮT ĐẦU ĐẶT BOM <<<
	# Gửi vị trí hiện tại của Player cho Enemy biết
	planting_bomb_started.emit(global_position)
	print("Player: Emitted planting_bomb_started at ", global_position) # Dòng debug
	
	# 2. Thực hiện logic đặt bom như cũ
	var tile_size = 16
	var bomb_position = Vector2(
		int(global_position.x / tile_size) * tile_size + tile_size / 2,
		int(global_position.y / tile_size) * tile_size + tile_size / 2
	)
	var bomb = BombScene.instantiate()
	get_parent().add_child(bomb) # Nên thêm vào một node cha chung (ví dụ Map) thay vì get_parent() trực tiếp
	bomb.global_position = bomb_position
	bomb_exists = true # Đánh dấu là đã có bom

	# Lắng nghe khi bomb nổ xong để cho phép đặt quả tiếp theo
	bomb.connect("bomb_exploded", Callable(self, "_on_bomb_exploded")) # Giữ nguyên dòng này

	# 3. >>> PHÁT TÍN HIỆU: KẾT THÚC HÀNH ĐỘNG ĐẶT BOM <<<
	# Vì việc đặt bom trong code này là tức thời, nên phát tín hiệu xong ngay
	planting_bomb_finished.emit()
	print("Player: Emitted planting_bomb_finished") # Dòng debug

func _on_bomb_exploded():
	# Được gọi khi quả bom phát tín hiệu "bomb_exploded"
	bomb_exists = false # Cho phép đặt quả bom tiếp theo

func update_animation(direction: Vector2) -> void:
	# (Giữ nguyên code animation của bạn)
	if direction == Vector2.ZERO:
		animated_sprite.animation = "idle_" + last_direction
	else:
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
