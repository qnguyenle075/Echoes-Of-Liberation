extends Node2D

@onready var WallTileMap = $kothepha
@onready var BrickTileMap = $brick
@onready var pause_menu := $Pausemenu
@onready var resume_button := $Pausemenu/VBoxContainer/remuse
@onready var quit_button := $Pausemenu/VBoxContainer/quit
@onready var play_again_button := $Pausemenu/VBoxContainer/playagain
@onready var CountDown := $CanvasLayer

const TILE_SIZE = 16

# Dùng RandomNumberGenerator riêng để random mạnh hơn
var rng = RandomNumberGenerator.new()

var WIDTH
var HEIGHT
var safe_spots = []

func _ready():
	rng.randomize() # Random lần đầu tiên khi vào game

	var used_rect = WallTileMap.get_used_rect()
	WIDTH = used_rect.size.x
	HEIGHT = used_rect.size.y

	setup_safe_spots()
	spawn_random_brick()
	
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)  
	
	Music.play_music("res://assets/Sound/Victory Reunited.mp3")
	CountDown.start_countdown(120)

func setup_safe_spots():
	safe_spots.clear()

	# Lấy tất cả player trong group "players"
	var players = get_tree().get_nodes_in_group("players")

	for player in players:
		var player_tile = WallTileMap.local_to_map(player.global_position)

		# Chừa vùng an toàn 3x3 quanh player
		for dx in range(-1, 2): # từ -1 tới 1
			for dy in range(-1, 2):
				var offset = Vector2i(dx, dy)
				var spot = player_tile + offset
				if not safe_spots.has(spot):
					safe_spots.append(spot)

	# Chừa thêm 4 góc ngoài map
	var corners = [
		Vector2i(0, 0),
		Vector2i(WIDTH-1, 0),
		Vector2i(0, HEIGHT-1),
		Vector2i(WIDTH-1, HEIGHT-1)
	]

	for corner in corners:
		safe_spots.append(corner)
		safe_spots.append(corner + Vector2i(1, 0))
		safe_spots.append(corner + Vector2i(0, 1))
		safe_spots.append(corner + Vector2i(1, 1))


func spawn_random_brick():
	for y in range(HEIGHT):
		for x in range(WIDTH):
			var tile_pos = Vector2i(x, y)

			# Nếu vị trí này nằm trong vùng an toàn thì bỏ qua
			if tile_pos in safe_spots:
				continue

			# Spawn Brick ngẫu nhiên 85% tỉ lệ
			if rng.randf() < 0.75:
				BrickTileMap.set_cell(tile_pos, 0, Vector2i(22,0))

var victory_triggered := false

func _process(_delta):
	if victory_triggered:
		return  # Đã xử lý rồi thì bỏ qua

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		victory_triggered = true
		await Music.play_sfx_and_wait("res://assets/Sound/level_complete.wav")
		get_tree().change_scene_to_file("res://scene/gameovermenu/victory.tscn")
		
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
		if get_tree().paused and pause_menu.visible:
			resume_game()  # Nếu đang pause và menu đang mở → resume
		else:
			pause_game()   # Nếu chưa pause → pause
			
			
func pause_game():
	get_tree().paused = true
	pause_menu.visible = true

func resume_game():
	get_tree().paused = false
	pause_menu.visible = false

func _on_resume_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	resume_game()
	
func _on_play_again_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	get_tree().paused = false
	get_tree().reload_current_scene()  # Load lại scene hiện tại

func _on_quit_pressed():
	Music.play_sfx("res://assets/Sound/retro-select-236670.mp3")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/mainmenu/main.tscn")
