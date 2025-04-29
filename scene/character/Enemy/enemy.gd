extends CharacterBody2D

# --- Constants ---
const SPEED = 40
const FLEE_SPEED = 60
const PLANT_BOMB_RANGE = 90.0
const PLANT_DURATION = 0.8
const BOMB_COOLDOWN = 3.0
const FLEE_DISTANCE = 150.0
const BOMB_DETECTION_RANGE = 180.0
const ARRIVAL_THRESHOLD = 5.0 # Khoảng cách coi như đã đến đích cuối cùng của path
const STUCK_CHECK_INTERVAL = 0.5 # Tần suất kiểm tra kẹt đường (giây)
const STUCK_VELOCITY_THRESHOLD = 2.0 # Ngưỡng vận tốc (pixel/giây) coi như bị kẹt

# --- Exports / Nodes ---
@export var player1: CharacterBody2D
@onready var nav_agent := $NavigationAgent2D as NavigationAgent2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var update_ai_timer := $UpdateAITimer as Timer
@onready var plant_bomb_timer := $PlantBombTimer as Timer
@onready var bomb_cooldown_timer := $BombCooldownTimer as Timer
# Timer và biến để kiểm tra kẹt đường
var stuck_check_timer := Timer.new()
var last_stuck_check_position: Vector2 = Vector2.ZERO

# --- AI State ---
enum State { CHASING, FLEEING, PLANTING_BOMB, COOLDOWN }
var current_state = State.CHASING
var flee_target_position: Vector2 = Vector2.ZERO # Lưu lại để biết đích chạy trốn
var is_planting_internal = false

# --- Bomb Scene ---
# !!! KIỂM TRA ĐƯỜNG DẪN và Đảm bảo Scene Bom có NavigationObstacle2D !!!
const EnemyBombScene = preload("res://scene/bomb/bomb.tscn")

# --- Player Bomb Detection State ---
var _player_is_planting = false
var _player_plant_pos = Vector2.ZERO

func _ready() -> void:
	print("DEBUG Enemy: _ready() called for ", name)
	# --- KIỂM TRA NODE QUAN TRỌNG ---
	if player1 == null: printerr("ERROR: Node Player1 CHƯA được gán!"); set_physics_process(false); return
	if not is_instance_valid(nav_agent): printerr("ERROR: Node 'NavigationAgent2D' không tìm thấy!"); set_physics_process(false); return
	if not is_instance_valid(animated_sprite): printerr("WARN: Node 'AnimatedSprite2D' not found.")
	if not is_instance_valid(plant_bomb_timer): printerr("ERROR: Node 'PlantBombTimer' không tìm thấy!"); set_physics_process(false); return
	if not is_instance_valid(bomb_cooldown_timer): printerr("ERROR: Node 'BombCooldownTimer' không tìm thấy!"); set_physics_process(false); return
	if not is_instance_valid(update_ai_timer): printerr("ERROR: Node 'UpdateAITimer' không tìm thấy!"); set_physics_process(false); return
	print("DEBUG Enemy: All essential Nodes seem valid.")

	# --- KẾT NỐI TÍN HIỆU PLAYER ---
	if is_instance_valid(player1):
		print("DEBUG Enemy: Player1 is valid in _ready.")
		if player1.has_signal("planting_bomb_started"):
			var err = player1.planting_bomb_started.connect(_on_player_planting_started)
			if err != OK: printerr("ERROR connecting planting_bomb_started! Code: ", err)
			else: print("DEBUG Enemy: Connected OK to planting_bomb_started.")
		else: printerr("ERROR: Player script missing 'planting_bomb_started' signal!")
		if player1.has_signal("planting_bomb_finished"):
			var err = player1.planting_bomb_finished.connect(_on_player_planting_finished)
			if err != OK: printerr("ERROR connecting planting_bomb_finished! Code: ", err)
			else: print("DEBUG Enemy: Connected OK to planting_bomb_finished.")
		else: printerr("WARNING: Player script missing 'planting_bomb_finished' signal!")
	else:
		printerr("ERROR: player1 instance became invalid during _ready!"); set_physics_process(false); return

	# --- THIẾT LẬP TIMERS ---
	plant_bomb_timer.wait_time = PLANT_DURATION; plant_bomb_timer.one_shot = true
	bomb_cooldown_timer.wait_time = BOMB_COOLDOWN; bomb_cooldown_timer.one_shot = true

	# Timer kiểm tra kẹt đường
	stuck_check_timer.name = "StuckCheckTimer"
	stuck_check_timer.wait_time = STUCK_CHECK_INTERVAL
	stuck_check_timer.one_shot = false # Chạy liên tục
	var stuck_conn_err = stuck_check_timer.timeout.connect(_on_stuck_check_timer_timeout)
	if stuck_conn_err != OK: printerr("ERROR connecting stuck_check_timer timeout! Code: ", stuck_conn_err)
	else: add_child(stuck_check_timer); stuck_check_timer.start(); print("DEBUG Enemy: StuckCheckTimer added and started.")
	last_stuck_check_position = global_position # Lưu vị trí ban đầu

	# Kết nối các timer nội bộ khác
	var plant_conn_err = plant_bomb_timer.timeout.connect(_on_plant_bomb_timer_timeout)
	if plant_conn_err != OK: printerr("ERROR connecting plant_bomb_timer timeout! Code: ", plant_conn_err)
	var cooldown_conn_err = bomb_cooldown_timer.timeout.connect(_on_bomb_cooldown_timer_timeout)
	if cooldown_conn_err != OK: printerr("ERROR connecting bomb_cooldown_timer timeout! Code: ", cooldown_conn_err)
	var update_conn_err = update_ai_timer.timeout.connect(update_ai_decision)
	if update_conn_err != OK: printerr("ERROR connecting update_ai_timer timeout! Code: ", update_conn_err)
	print("DEBUG Enemy: Internal timers connected.")

	# --- BẮT ĐẦU AI ---
	update_ai_decision()
	update_ai_timer.start()
	print("DEBUG Enemy: _ready() finished successfully.")

# --- Player Signal Handlers ---
func _on_player_planting_started(pos: Vector2):
	print("DEBUG Enemy Signal: Received _on_player_planting_started! Pos:", pos)
	_player_is_planting = true
	_player_plant_pos = pos
	if is_instance_valid(animated_sprite): animated_sprite.modulate = Color.RED # Đổi màu debug
	update_ai_decision() # Đánh giá lại ngay

func _on_player_planting_finished():
	print("DEBUG Enemy Signal: Received _on_player_planting_finished!")
	_player_is_planting = false # Chỉ cập nhật cờ, không gọi update_ai_decision
	if is_instance_valid(animated_sprite): animated_sprite.modulate = Color.WHITE # Trả màu

# --- Core Logic ---
func _physics_process(delta: float) -> void:
	if not is_instance_valid(nav_agent): return

	# Lấy vận tốc an toàn từ NavigationAgent
	var safe_velocity = nav_agent.get_velocity()
	velocity = safe_velocity
	move_and_slide()
	nav_agent.set_velocity(velocity) # Thông báo vận tốc thực tế cho agent

	# Xử lý logic và đặt tốc độ mong muốn cho frame SAU
	var desired_speed = SPEED
	match current_state:
		State.FLEEING:
			desired_speed = FLEE_SPEED
			# --- SỬA LỖI NGỪNG NÉ SỚM ---
			# Chỉ thoát khỏi FLEEING khi thực sự đến đích chạy trốn
			if nav_agent.is_target_reached():
				print("DEBUG Enemy Physics: Fleeing target reached.")
				# Quan trọng: Reset về CHASING để update_ai_decision có thể hoạt động đúng
				set_state(State.CHASING)
				print("DEBUG Enemy Physics: Reset state to CHASING, now updating AI.")
				update_ai_decision() # Bây giờ mới quyết định lại
			# Nếu chưa đến đích -> calculate_and_set_agent_velocity sẽ giữ tốc độ FLEE_SPEED

		State.CHASING, State.COOLDOWN, State.PLANTING_BOMB:
			desired_speed = SPEED

	# Tính toán và set velocity mong muốn cho frame tiếp theo *sau khi* đã xử lý logic trạng thái
	calculate_and_set_agent_velocity(desired_speed)


func calculate_and_set_agent_velocity(speed: float):
	"""Tính toán velocity mong muốn và đặt nó cho NavigationAgent."""
	if not is_instance_valid(nav_agent): return

	var desired_velocity = Vector2.ZERO
	# Chỉ tính velocity nếu agent còn đường đi và chưa đến đích cuối cùng
	if nav_agent.is_target_reachable() and not nav_agent.is_target_reached():
		var next_path_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_pos)
		desired_velocity = direction * speed
	# Đặt vận tốc mong muốn cho agent để nó tính toán avoidance cho frame sau
	nav_agent.set_velocity(desired_velocity)


# --- HÀM AI DECISION ĐÃ SỬA ĐỂ KHÔNG THOÁT FLEEING SỚM ---
func update_ai_decision():
	# --- QUAN TRỌNG: Nếu đang chạy thì không quyết định gì khác ---
	# Logic thoát Fleeing giờ nằm trong _physics_process khi đến đích
	if current_state == State.FLEEING:
		#print("DEBUG Enemy AI: Currently FLEEING, skipping other decisions.")
		return # Để _physics_process xử lý việc hoàn thành đường chạy

	# --- Các kiểm tra và quyết định khác ---
	if not is_instance_valid(player1):
		print("DEBUG Enemy AI: Player1 invalid."); set_state(State.CHASING); velocity = Vector2.ZERO; return

	print("DEBUG Enemy AI: Updating AI decision. State:", State.keys()[current_state], "_player_is_planting =", _player_is_planting)
	var player_planting_info = check_if_player_is_planting_bomb()
	#print("DEBUG Enemy AI: check_if_player_is_planting_bomb returned: ", player_planting_info)

	# Ưu tiên 1: Bắt đầu Flee (Chỉ gọi nếu chưa Fleeing)
	if player_planting_info.is_planting: # Không cần check current_state != FLEEING nữa vì đã return ở trên
		print("DEBUG Enemy AI: Condition MET - Start fleeing!")
		start_fleeing(player_planting_info.position)
		return # Bắt đầu chạy là xong việc của hàm này

	# Ưu tiên 2: Plant Bomb (Nếu không đang Fleeing - đã được đảm bảo bởi return ở trên)
	var distance_to_player = global_position.distance_to(player1.global_position)
	if distance_to_player < PLANT_BOMB_RANGE and bomb_cooldown_timer.is_stopped() and not is_planting_internal:
		print("DEBUG Enemy AI: Condition MET - Start planting bomb!")
		start_planting_bomb()
		# Không return, vẫn có thể cần update target chasing ngay sau đó

	# Ưu tiên 3: Chasing / Cooldown (Hành động mặc định khi không flee và không plant)
	# Khối lệnh này chỉ chạy nếu không Flee và không vừa quyết định Plant
	var target_position = player1.global_position
	if not bomb_cooldown_timer.is_stopped():
		# Nếu đang hồi chiêu và không phải đang plant -> COOLDOWN
		if not is_planting_internal: set_state(State.COOLDOWN)
		update_navigation_target(target_position)
	elif not is_planting_internal: # Nếu không hồi chiêu và không plant -> CHASING
		set_state(State.CHASING)
		update_navigation_target(target_position)
	# Nếu đang plant (is_planting_internal = true), thì vẫn update target để đuổi theo
	elif current_state == State.PLANTING_BOMB:
		update_navigation_target(target_position)


func set_state(new_state: State):
	# (Giữ nguyên hàm này)
	if current_state != new_state:
		print("DEBUG Enemy State: Changing from ", State.keys()[current_state], " to ", State.keys()[new_state])
		current_state = new_state

# --- Helper Functions ---
func check_if_player_is_planting_bomb() -> Dictionary:
	# (Giữ nguyên hàm này)
	if _player_is_planting:
		var dist = global_position.distance_to(_player_plant_pos)
		#print("DEBUG Enemy Check: Player is planting. Dist:", dist, "Range:", BOMB_DETECTION_RANGE)
		if dist < BOMB_DETECTION_RANGE: return {"is_planting": true, "position": _player_plant_pos}
	return {"is_planting": false, "position": Vector2.ZERO}

func update_navigation_target(target_pos: Vector2):
	# (Giữ nguyên hàm này)
	if is_instance_valid(nav_agent): nav_agent.target_position = target_pos
	else: printerr("ERROR: nav_agent is null in update_navigation_target!")

# --- Action Functions ---
func start_fleeing(danger_position: Vector2):
	# --- SỬA LẠI ĐỂ TÌM ĐIỂM HỢP LỆ TRÊN MAP ---
	print("DEBUG Enemy Action: Executing start_fleeing.")
	# Ngắt quãng planting nếu đang diễn ra
	if is_planting_internal:
		plant_bomb_timer.stop(); is_planting_internal = false
		print("DEBUG Enemy Action: Planting interrupted by fleeing!")

	set_state(State.FLEEING)

	# Tính toán hướng chạy trốn
	var flee_direction = Vector2.ZERO
	if (global_position - danger_position).length_squared() > 0.001:
		flee_direction = (global_position - danger_position).normalized()
	else:
		flee_direction = Vector2.RIGHT.rotated(randf_range(0, TAU)) # Hướng ngẫu nhiên nếu trùng vị trí
		print("WARN: Fleeing from same position, using random direction.")

	# Tính toán điểm đích "lý tưởng" xa ra theo hướng đó
	var ideal_flee_point = global_position + flee_direction * FLEE_DISTANCE

	# Tìm điểm hợp lệ gần nhất trên navigation map
	var nav_map_rid = get_world_2d().navigation_map
	var safe_flee_point = NavigationServer2D.map_get_closest_point(nav_map_rid, ideal_flee_point)

	print("DEBUG Enemy Action: Ideal Flee Point:", ideal_flee_point, " | Safe Flee Point on Map:", safe_flee_point)
	# Đặt target cho nav agent là điểm an toàn đã tìm được
	flee_target_position = safe_flee_point # Lưu lại điểm đích chạy trốn thực tế
	update_navigation_target(safe_flee_point)

	# Kiểm tra lại xem điểm an toàn này có thực sự đến được không
	if is_instance_valid(nav_agent) and not nav_agent.is_target_reachable():
		print("WARN: SAFE flee target is STILL not reachable! Problem with NavigationMap or target calculation.")
		# Nếu điểm an toàn nhất vẫn ko tới được, quay về chasing để tránh bị kẹt hoàn toàn
		set_state(State.CHASING)
		update_ai_decision()


func start_planting_bomb():
	# (Giữ nguyên hàm này)
	print("DEBUG Enemy Action: Executing start_planting_bomb.")
	set_state(State.PLANTING_BOMB)
	is_planting_internal = true
	plant_bomb_timer.start()

# --- Timer Timeout Functions ---
func _on_stuck_check_timer_timeout():
	# (Giữ nguyên hàm này)
	if is_instance_valid(nav_agent) and not nav_agent.is_target_reached() \
	   and (current_state == State.CHASING or current_state == State.COOLDOWN or current_state == State.FLEEING):
		var distance_moved = global_position.distance_to(last_stuck_check_position)
		var min_velocity_threshold = STUCK_VELOCITY_THRESHOLD
		if distance_moved < min_velocity_threshold * stuck_check_timer.wait_time :
			print("WARN: Enemy might be stuck! Moved only", distance_moved, "px in", stuck_check_timer.wait_time, "s. Forcing AI update.")
			update_ai_decision()
		last_stuck_check_position = global_position

func _on_plant_bomb_timer_timeout():
	# (Giữ nguyên hàm này, bao gồm kiểm tra state và is_planting_internal)
	print("DEBUG Enemy Timer: _on_plant_bomb_timer_timeout called.")
	if current_state == State.PLANTING_BOMB and is_planting_internal:
		var bomb_instance = EnemyBombScene.instantiate()
		bomb_instance.global_position = global_position + Vector2(0, 8)
		var parent_node = get_parent()
		if is_instance_valid(parent_node): parent_node.add_child(bomb_instance); print("DEBUG Enemy Action: Enemy PLANTED BOMB.")
		else: printerr("ERROR: Cannot add bomb, Enemy has no parent!")
		is_planting_internal = false
		bomb_cooldown_timer.start()
		set_state(State.COOLDOWN)
		update_ai_decision()
	else:
		print("DEBUG Enemy Timer: Plant timer timeout ignored, state:", State.keys()[current_state], "planting:", is_planting_internal)
		is_planting_internal = false

func _on_bomb_cooldown_timer_timeout():
	# (Giữ nguyên hàm này)
	print("DEBUG Enemy Timer: _on_bomb_cooldown_timer_timeout called.")
	update_ai_decision() # Đánh giá lại tình hình
