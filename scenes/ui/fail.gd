extends Control

const REASONS := [
	"怪是吃饱了，你是失败了",
	"你成为了怪美味可口的宵夜!",
	"停停停这怪你对吗",
	"666怪玩不起搞偷袭",
	"怪宝子你继续阴我",
	"怪喜欢吃人这一块",
	"这把我的我的，下把再来",
	"这怪刷的是不是有点少了",
	"这怪敢再刷多点吗",
]

const BoatScenePath := "res://scenes/boat_scene.tscn"
const FINAL_FAILURE_TEXT := "信号丢失……？……我们失去了她。\n任务失败。继续派遣下一批科学家……必须弄清地球发生了什么……"


func _ready() -> void:
	var music_mgr: Node = get_node_or_null("/root/MusicManager")
	if music_mgr != null:
		music_mgr.play_fail_scene_music()

	var reason_label: Label = $reason as Label
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var progress: Node = get_node_or_null("/root/ProgressState")
	if progress != null and progress.has_method("get_story_ending") and String(progress.get_story_ending()) == "failure":
		$title.text = "通讯中断"
		reason_label.text = FINAL_FAILURE_TEXT
		reason_label.add_theme_font_size_override("font_size", 38)
	else:
		reason_label.text = REASONS[randi() % REASONS.size()]

	var back_button: Button = $back as Button
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(BoatScenePath)
