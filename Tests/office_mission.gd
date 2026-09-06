extends Node
var checks := 0
var failures := 0
var q
var b
var p
var scene
const HALL = "res://Scenes/andar_hall.tscn"
const ID = "hall:hall_quest_01:pos_saida_2"
var output: String

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_test")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func settle():
	await get_tree().process_frame
	await get_tree().process_frame
	scene = get_tree().current_scene
	p = scene.player
	b = p.balao_de_pensamento
	q = scene.get_node_or_null("QUEST_MISSION")

func reload_checkpoint():
	check(SaveGame.load_last_checkpoint(), "checkpoint load accepted")
	await get_tree().scene_changed
	await settle()

func finish_one():
	if b._fase == "exibicao":
		b._tween.custom_step(b._duracao + 0.01)
	if b._fase == "fade":
		b._tween.custom_step(b._duracao + 0.01)

func capture(file: String):
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(file)) == OK, "render saved: " + file)

func gate_check(message: String):
	var trigger = scene.get_node("SceneTrigger2")
	trigger._on_body_entered(p)
	var pos = p.global_position
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	trigger._input(event)
	trigger.usar_elevador(4)
	check(not get_tree().paused and pos == p.global_position and not scene.get_node("PainelElevador").visible and trigger.get_node("Timer").is_stopped(), message)

func run_test():
	if not str(ProjectSettings.get_setting("application/config/name")).begins_with("ASIMOV Office Validation"):
		push_error("Run only in an isolated project copy")
		get_tree().quit(2)
		return
	output = OS.get_environment("ASIMOV_TEST_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	print("USER DATA: ", OS.get_user_data_dir())
	print("RENDERER: ", RenderingServer.get_video_adapter_name())
	get_tree().current_scene = null
	SaveGame.clear_save()
	get_tree().change_scene_to_file(HALL)
	await get_tree().scene_changed
	await settle()
	gate_check("elevator blocked before final thought, including destination 4")
	check(not scene.get_node("OfficeMission").visible, "office objective absent before thought")
	SaveGame.create_checkpoint(p)
	await reload_checkpoint()
	gate_check("gate preserved on early load")
	finish_one()
	var first = scene.get_node("Interativos/Line2D")
	check(first.visible and first._luzes.size() == 4, "first indicator begins with four lights")
	await get_tree().create_timer(10.2).timeout
	check(not is_instance_valid(first) and scene.get_node_or_null("Interativos/PointLight2D") == null, "first cycle queue_free after ten active seconds")
	# Drive the real fire scripts and rock mission event; NPCs follow their real routes.
	for name in ["Fogo3", "Fogo5", "Fogo6"]:
		scene.get_node("Perigos/" + name).apagar_fogo()
	q._on_area_2d_body_entered(scene.get_node("Coletaveis/pedaco1"))
	finish_one()
	var deadline = Time.get_ticks_msec() + 45000
	while b.pensamento_atual_id() != ID and Time.get_ticks_msec() < deadline:
		if b.pensamento_atual_id().ends_with("pos_saida_1"):
			finish_one()
		await get_tree().create_timer(0.1).timeout
	check(q._todos_sairam and b.pensamento_atual_id() == ID, "real NPC exit routes lead to office thought")
	gate_check("gate remains closed during office thought")
	check(not scene.get_node("OfficeMission").visible, "objective still absent during office thought")
	SaveGame.create_checkpoint(p)
	var midway = SaveGame.state_player.pensamentos.duplicate(true)
	await reload_checkpoint()
	check(b.pensamento_atual_id() == ID and b._fase == midway.fase, "active thought and phase restored")
	gate_check("gate remains closed after mid-thought load")
	finish_one()
	await settle()
	var state = SaveGame.office_mission_state()
	var row = scene.get_node("OfficeMission/VBoxContainer/HBoxContainer")
	check(state.elevator_third_floor_unlocked and not state.arrived_third_floor, "thought completion unlocks without arrival")
	check(scene.get_node("OfficeMission").visible and row.get_node("AnimatedSprite2D").frame == 0, "new objective visible and unchecked")
	check(row.get_node("Label3").get_theme_font_size("font_size") > 0 and row.get_node("Label3").label_settings.font_size == 9, "same pixel font size as existing tasks")
	var second = scene.get_node("Interativos/ElevatorIndicator/Line2D")
	check(second.visible and second._luzes.size() == 4 and second._luzes.all(func(light): return is_instance_valid(light) and light.visible), "new border with four recreated sibling lights")
	p.global_position = Vector2(-24, -80)
	scene.atualizar_camera()
	await capture("hall-objective.png")
	var before = second._temporizador.time_left
	get_tree().paused = true
	await get_tree().create_timer(0.5).timeout
	check(is_equal_approx(before, second._temporizador.time_left) and not second.visible, "pause freezes indicator countdown and hides it")
	get_tree().paused = false
	await settle()
	check(second.visible, "indicator resumes after pause")
	SaveGame.create_checkpoint(p)
	var remaining = SaveGame.office_mission_state().indicator_remaining
	await reload_checkpoint()
	second = scene.get_node("Interativos/ElevatorIndicator/Line2D")
	check(abs(second._temporizador.time_left - remaining) < 0.15, "load resumes remaining indicator duration")
	var timer_left = second._temporizador.time_left
	await get_tree().create_timer(timer_left + 0.2).timeout
	check(not is_instance_valid(second) and not scene.has_node("Interativos/ElevatorIndicator"), "second cycle queue_free including lights after remaining active time")
	SaveGame.create_checkpoint(p)
	await reload_checkpoint()
	check(not scene.has_node("Interativos/ElevatorIndicator"), "expired second indicator does not restart on load")
	# Travel through a different floor before selecting the third.
	scene_manager.change_scene(p, "andar_ferramentas")
	await get_tree().scene_changed
	await settle()
	check(scene.get_node("OfficeMission").visible and not SaveGame.office_mission_state().arrived_third_floor, "objective follows player to fourth floor unchecked")
	SaveGame.create_checkpoint(p)
	await reload_checkpoint()
	check(scene.get_node("OfficeMission").visible and not SaveGame.office_mission_state().arrived_third_floor, "save/load on fourth preserves pending mission")
	var rollback = SaveGame.checkpoint_world_state.duplicate(true)
	var trigger
	for node in scene.get_children():
		if node is SceneTrigger and node.eh_elevador:
			trigger = node
	trigger._on_body_entered(p)
	trigger.usar_elevador(3)
	check(not SaveGame.office_mission_state().arrived_third_floor, "destination selection does not complete mission")
	await get_tree().scene_changed
	await settle()
	check(scene.scene_file_path.ends_with("andar_escritorio.tscn") and SaveGame.office_mission_state().arrived_third_floor, "arrival in office completes mission")
	check(p.global_position.distance_to(scene.get_node("EntranceMarkers/any").global_position) < 1.0 and SaveGame.checkpoint_pos == p.global_position, "completion checkpoint captures actual entrance position")
	check(scene.get_node("OfficeMission/VBoxContainer/HBoxContainer/AnimatedSprite2D").is_playing(), "arrival starts existing check animation")
	await get_tree().create_timer(0.5).timeout
	await capture("office-complete.png")
	await reload_checkpoint()
	check(scene.get_node("OfficeMission/VBoxContainer/HBoxContainer/AnimatedSprite2D").frame == 1, "completed check restored from arrival save")
	SaveGame.checkpoint_world_state = rollback
	SaveGame.checkpoint_scene_path = "res://Scenes/andar_ferramentas.tscn"
	await reload_checkpoint()
	check(not SaveGame.office_mission_state().arrived_third_floor and scene.get_node("OfficeMission/VBoxContainer/HBoxContainer/AnimatedSprite2D").frame == 0, "rollback removes later arrival and completed check")
	# Legacy save migration from completed thought, without new quest/global fields.
	SaveGame.save_data.erase("__global")
	var hall = SaveGame.save_data[HALL]["hall_quest_01"]
	hall.erase("elevator_third_floor_unlocked")
	hall.erase("arrived_third_floor")
	check(SaveGame.office_mission_state(p).elevator_third_floor_unlocked, "legacy completed thought migrates unlocked mission")
	SaveGame.save_data.erase("__global")
	b.load_checkpoint_state({})
	check(not SaveGame.office_mission_state(p).elevator_third_floor_unlocked, "legacy incomplete thought keeps gate closed")
	# Reset from pause exercises deferred callbacks while old scene is removed.
	get_tree().paused = true
	get_tree().paused = false
	await reload_checkpoint()
	print("RESULT: ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
