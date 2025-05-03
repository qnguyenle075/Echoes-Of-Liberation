extends CanvasLayer

@onready var time_label := $Control/Label
var timer := Timer.new()
var running := false
var time_left

func _ready():
	add_child(timer)
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(_on_tick)

	hide()  # Ẩn ban đầu

func start_countdown(seconds: int):
	time_left = seconds
	running = true
	update_label()
	show()
	timer.start()

func stop_countdown():
	timer.stop()
	hide()
	running = false

func _on_tick():
	time_left -= 1
	update_label()
	if time_left <= 0:
		timer.stop()
		if !_all_enemies_dead():
			_on_game_over()

func update_label():
	if time_label:
		time_label.text = "Time Remain: " + format_time(time_left)

func format_time(seconds: int) -> String:
	var mins = seconds / 60
	var secs = seconds % 60
	return "%02d:%02d" % [mins, secs]

func _all_enemies_dead() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	return enemies.size() == 0

func _on_game_over():
	await Music.play_sfx_and_wait("res://assets/Sound/game_over.wav")
	get_tree().change_scene_to_file("res://scene/gameovermenu/gameover.tscn")
