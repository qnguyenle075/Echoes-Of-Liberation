extends Node2D

@onready var pause_menu := $Pausemenu
@onready var resume_button := $Pausemenu/VBoxContainer/remuse
@onready var quit_button := $Pausemenu/VBoxContainer/quit
@onready var play_again_button := $Pausemenu/VBoxContainer/playagain
@onready var CountDown := $CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	pause_menu.visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)  
	
	Music.play_music("res://assets/Sound/Pixel Frenzy.mp3")
	CountDown.start_countdown(180)

# Called every frame. 'delta' is the elapsed time since the previous frame.
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
