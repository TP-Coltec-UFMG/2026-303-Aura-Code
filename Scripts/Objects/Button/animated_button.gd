extends Button

@export_category("Hover")
@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var hover_animation_length: float = 0.1
@export var un_hover_animation_length: float = 0.1

@export_category("Press")
@export var press_scale: Vector2 = Vector2(0.95, 0.95)
@export var press_animation_length_1: float = 0.1
@export var press_animation_length_2: float = 0.1

var animation_tween: Tween
var original_scale: Vector2


func _ready() -> void:
	original_scale = scale

	pressed.connect(_button_press)
	mouse_entered.connect(_button_hover)
	mouse_exited.connect(_button_un_hover)
	focus_entered.connect(_button_hover)
	focus_exited.connect(_button_un_hover)
	resized.connect(update_pivot)

	update_pivot()


func update_pivot() -> void:
	pivot_offset = size / 2.0


func _button_press() -> void:
	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween().set_trans(Tween.TRANS_SINE)

	animation_tween.tween_property(
		self,
		"scale",
		original_scale * press_scale,
		press_animation_length_1
	)

	animation_tween.chain().tween_property(
		self,
		"scale",
		original_scale * hover_scale,
		press_animation_length_2
	)


func _button_hover() -> void:
	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween().set_trans(Tween.TRANS_SINE)

	animation_tween.tween_property(
		self,
		"scale",
		original_scale * hover_scale,
		hover_animation_length
	)


func _button_un_hover() -> void:
	if animation_tween:
		animation_tween.kill()

	animation_tween = create_tween().set_trans(Tween.TRANS_SINE)

	animation_tween.tween_property(
		self,
		"scale",
		original_scale,
		un_hover_animation_length
	)
