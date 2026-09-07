extends MarginContainer

signal dialog_finished()

var texts_to_display: Array[String] = []
var current_index: int = 0
var typing_speed: float = 0.05
var is_typing: bool = false
var skip_typing: bool = false

@onready var text_label: Label = $text_container/text_label
@onready var indicator: TextureRect = $indicator
@onready var tween: Tween = get_tree().create_tween()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	pivot_offset = size / 2
	scale = Vector2.ZERO
	indicator.visible = false

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.3
	).set_trans(Tween.TRANS_BACK)

func show_text() -> void:
	if current_index < texts_to_display.size():
		is_typing = true
		skip_typing = false
		indicator.visible = false
		text_label.text = ""

		_type_text(texts_to_display[current_index])
	else:
		_close_dialog()

func _type_text(text: String) -> void:
	for i in range(text.length()):
		if skip_typing:
			text_label.text = text
			break

		text_label.text += text[i]
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	indicator.visible = true

func _close_dialog():
	is_typing = true

	@warning_ignore("shadowed_variable")
	var tween = get_tree().create_tween()
	tween.tween_property(
		self,
		"scale",
		Vector2.ZERO,
		0.3
	).set_trans(Tween.TRANS_BACK)

	await tween.finished

	dialog_finished.emit()
	queue_free()

func advance() -> void:
	if is_typing:
		skip_typing = true
	elif current_index + 1 < texts_to_display.size():
		current_index += 1
		show_text()
	else:
		_close_dialog()
