extends Control

const REASONS := [
	"章鱼吃饱了，而你的任务失败了",
	"你成为了章鱼美味可口的宵夜!",
	"停停停章鱼你对吗",
	"666章鱼玩不起搞偷袭",
	"章鱼宝子你继续阴我",
	"章鱼喜欢吃人这一块",
	"这把我的我的，下把再来",
]

const BoatScenePath := "res://scenes/boat_scene.tscn"


func _ready() -> void:
	var music_mgr: Node = get_node_or_null("/root/MusicManager")
	if music_mgr != null:
		music_mgr.play_fail_scene_music()

	var reason_label: Label = $reason as Label
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.text = REASONS[randi() % REASONS.size()]

	var back_button: Button = $back as Button
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(BoatScenePath)
