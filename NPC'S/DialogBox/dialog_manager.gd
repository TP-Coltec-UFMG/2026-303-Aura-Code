extends CanvasLayer

signal dialog_started(dialog_id: String)
signal dialog_finished(dialog_id: String)

@export var dialog_scene: PackedScene

var dialog_box = null
var is_showing_dialog: bool = false
var current_dialog_id: String = ""


func _input(event: InputEvent) -> void:
	if not is_showing_dialog or dialog_box == null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		dialog_box.advance()

func start_dialog(texts: Array[String], dialog_id: String = "") -> void:
	if is_showing_dialog:
		return

	if dialog_scene:
		dialog_box = dialog_scene.instantiate()
		current_dialog_id = dialog_id
		is_showing_dialog = true

		add_child(dialog_box)

		dialog_box.texts_to_display = texts

		dialog_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_box.offset_left = 16
		dialog_box.offset_right = -16
		dialog_box.offset_top = -120 
		dialog_box.offset_bottom = -16

		dialog_box.dialog_finished.connect(_on_dialog_finished)
		dialog_box.show_text()
		dialog_started.emit(current_dialog_id)

func _on_dialog_finished() -> void:
	var finished_dialog_id := current_dialog_id
	is_showing_dialog = false
	current_dialog_id = ""

	if dialog_box:
		dialog_box = null

	dialog_finished.emit(finished_dialog_id)
