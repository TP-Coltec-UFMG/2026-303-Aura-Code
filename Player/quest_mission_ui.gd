class_name QuestMissionUI
extends CanvasLayer

@onready var rows: Array[HBoxContainer] = [
	$VBoxContainer/HBoxContainer2,
	$VBoxContainer/HBoxContainer,
	$VBoxContainer/HBoxContainer3,
	$VBoxContainer/HBoxContainer4,
]
@onready var markers: Array[AnimatedSprite2D] = [
	$VBoxContainer/HBoxContainer2/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer3/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer4/AnimatedSprite2D,
]

var desired_visible: bool = false
var hidden_for_elevator: bool = false


func _enter_tree() -> void:
	if hidden_for_elevator:
		call_deferred("_restore_after_scene_change")


func _ready() -> void:
	rows[2].hide()
	rows[3].hide()
	hide()
	call_deferred("refresh_saved_state")


func set_panel_visible(value: bool) -> void:
	desired_visible = value
	visible = value and not get_tree().paused and not hidden_for_elevator


func hide_during_elevator() -> void:
	hidden_for_elevator = true
	hide()


func restore_after_elevator() -> void:
	hidden_for_elevator = false
	visible = desired_visible and not get_tree().paused


func _restore_after_scene_change() -> void:
	if is_inside_tree() and hidden_for_elevator:
		restore_after_elevator()


func set_task_visible(index: int, value: bool) -> void:
	if index >= 0 and index < rows.size():
		rows[index].visible = value


func set_task_text(index: int, value: String) -> void:
	if index >= 0 and index < rows.size():
		(rows[index].get_node("Label3") as Label).text = value


func set_task_completed(index: int, completed: bool, animate: bool = false) -> void:
	if index < 0 or index >= markers.size():
		return
	var marker := markers[index]
	marker.stop()
	marker.animation = &"default"
	if completed and animate:
		marker.play(&"default")
	elif completed:
		marker.frame = maxi(marker.sprite_frames.get_frame_count(&"default") - 1, 0)
	else:
		marker.frame = 0
		marker.frame_progress = 0.0


func complete_third_floor() -> void:
	show_only_third_floor_task(true, true)


func show_only_third_floor_task(completed: bool, animate: bool = false) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 3)
	set_task_text(3, "IR PARA O TERCEIRO ANDAR")
	set_task_completed(3, completed, animate)
	set_panel_visible(true)


func show_talk_to_npc_task(completed: bool, animate: bool = false) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 3)
	set_task_text(3, "FALE COM O NPC")
	set_task_completed(3, completed, animate)
	set_panel_visible(true)


func refresh_saved_state() -> void:
	var state := SaveGame.office_mission_state(get_parent() as Player)
	var unlocked := bool(state.get("elevator_third_floor_unlocked", false))
	var arrived := bool(state.get("arrived_third_floor", false))
	var npc_ready := bool(state.get("office_npc_shout_finished", false))
	var dialog_finished := bool(state.get("office_dialog_finished", false))
	if unlocked:
		set_task_completed(0, true)
		set_task_completed(1, true)
		set_task_completed(2, true)
		if npc_ready:
			show_talk_to_npc_task(dialog_finished)
		else:
			show_only_third_floor_task(arrived)
	else:
		set_task_visible(3, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED and is_node_ready() and not hidden_for_elevator:
		restore_after_elevator()
