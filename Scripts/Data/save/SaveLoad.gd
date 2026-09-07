extends Node

const FILE_PATH: String = "user://SaveFileConfigs.json"

const REMAPPABLE_ACTIONS: PackedStringArray = [
	"up",
	"down",
	"right",
	"left",
	"correr",
	"empurrar",
	"interact",
	"use_lanterna",
	"use_arma",
	"use_cartao",
	"use_laptop",
	"use_cabo",
	"use_extintor",
	"acende_lanterna",
	"usar_extintor",
	"fire",
	"esc"
]


var save_data: Dictionary = {
	"traducao": "PORTUGUÊS",
	"volume_geral": 1.0,
	"volume_musica": 0.1,
	"volume_sfx": 0.0,
	"tela_cheia" : false,
	"filtro_de_daltonismo" : 0,
	"intensidade_filtro_daltonismo" : 1.0,
	"frame_rate" : 0,
	"mostrar_fps" : false,
	"legenda_ativa" : false,
	"tamanho_legenda" : 10,
	"primeira_vez" : true,
	"leitor_de_tela" : false,
	"velocidade_leitor_de_tela" : 1.0,
	"volume_leitor": 1.0,
	"alto_contraste" : false,
	"cor_alto_contraste" : Color.YELLOW,
	"input_bindings": {},
	"interface_size" : 0,
	"tutorial_seen" : false,
	"tutorial_completed" : false,
	"job": "",
	"character": "",
	"difficulty": ""
}

func _ready() -> void:
	_load()


func _save() -> void:
	# Alguns menus antigos substituem save_data pelo dicionário de Configs.
	# Sincronizar aqui mantém o salvamento correto independentemente de qual
	# tela solicitou a gravação e inclui sempre os controles atuais.
	for key: Variant in Configs.configs:
		save_data[key] = Configs.configs[key]

	var input_bindings: Dictionary = _capture_input_bindings()
	save_data["input_bindings"] = input_bindings
	Configs.configs["input_bindings"] = input_bindings.duplicate(true)

	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível abrir o arquivo de configurações para escrita.")
		return
	file.store_var(save_data)
	file.close()


func _load() -> void:
	if FileAccess.file_exists(FILE_PATH):
		var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.READ)
		if file == null:
			push_warning("Não foi possível abrir o arquivo de configurações para leitura.")
			return
		var loaded_value: Variant = file.get_var()
		if not loaded_value is Dictionary:
			file.close()
			push_warning("O arquivo de configurações está inválido.")
			return

		var data: Dictionary = loaded_value
		for key: Variant in data:
			if save_data.has(key):
				save_data[key] = data[key]
		file.close()

	# Também aplica os padrões na primeira execução, quando ainda não existe
	# arquivo. Assim o controlador de música não precisa sobrescrever volumes.
	_apply_load()


func _apply_load() -> void:
	Configs.configs = save_data.duplicate(true)

	TranslationServer.set_locale(save_data.traducao)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(save_data.volume_geral)
	)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(save_data.volume_musica)
	)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("sfx"),
		linear_to_db(save_data.volume_sfx)
	)

	if save_data.tela_cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

	if is_instance_valid(FiltroDaltonismo):
		FiltroDaltonismo.call_deferred(
			"aplicar_filtro",
			save_data.filtro_de_daltonismo,
			save_data.intensidade_filtro_daltonismo
		)

	Engine.max_fps = save_data.frame_rate

	_apply_input_bindings(
		save_data.get("input_bindings", {})
	)

	var contrast_color_value: Variant = save_data.get(
		"cor_alto_contraste",
		Color.YELLOW
	)
	var contrast_color: Color = Color.YELLOW

	if contrast_color_value is Color:
		contrast_color = contrast_color_value as Color
	else:
		contrast_color = Color.from_string(
			str(contrast_color_value),
			Color.YELLOW
		)

	contrast_color.a = 1.0
	save_data["cor_alto_contraste"] = contrast_color
	Configs.configs["cor_alto_contraste"] = contrast_color

	HighContrast.set_accent_color(contrast_color)
	HighContrast.set_enabled(save_data.alto_contraste)


func save_input_bindings() -> void:
	_save()
	get_tree().call_group(
		&"inventory_binding_slots",
		&"refresh_bind_label"
	)


func _capture_input_bindings() -> Dictionary:
	var bindings: Dictionary = {}

	for action_name: String in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action_name):
			continue

		var serialized_events: Array = []

		for input_event: InputEvent in InputMap.action_get_events(action_name):
			var event_data: Dictionary = _serialize_input_event(input_event)

			if not event_data.is_empty():
				serialized_events.append(event_data)

		bindings[action_name] = serialized_events

	return bindings


func _apply_input_bindings(value: Variant) -> void:
	if not value is Dictionary:
		return

	var bindings: Dictionary = value.duplicate(true)
	# Migra a tecla personalizada de configurações salvas antes da troca do item.
	if not bindings.has("use_cabo") and bindings.has("use_faca"):
		bindings["use_cabo"] = bindings["use_faca"]

	for action_key: Variant in bindings:
		var action_name := str(action_key)

		if not REMAPPABLE_ACTIONS.has(action_name):
			continue

		if not InputMap.has_action(action_name):
			continue

		var serialized_events: Variant = bindings[action_key]

		if not serialized_events is Array:
			continue

		var restored_events: Array[InputEvent] = []

		for event_value: Variant in serialized_events:
			var input_event: InputEvent = _deserialize_input_event(event_value)

			if input_event != null:
				restored_events.append(input_event)

		# Um registro vazio ou corrompido nunca remove o controle padrão.
		if restored_events.is_empty():
			continue

		InputMap.action_erase_events(action_name)

		for input_event: InputEvent in restored_events:
			InputMap.action_add_event(action_name, input_event)

	get_tree().call_group(
		&"inventory_binding_slots",
		&"refresh_bind_label"
	)


func _serialize_input_event(input_event: InputEvent) -> Dictionary:
	var data: Dictionary = {
		"device": input_event.device
	}

	if input_event is InputEventKey:
		var key_event := input_event as InputEventKey
		data["type"] = "key"
		data["keycode"] = key_event.keycode
		data["physical_keycode"] = key_event.physical_keycode
		data["key_label"] = key_event.key_label
		data["unicode"] = key_event.unicode
		_store_modifiers(data, key_event)
	elif input_event is InputEventMouseButton:
		var mouse_event := input_event as InputEventMouseButton
		data["type"] = "mouse_button"
		data["button_index"] = mouse_event.button_index
		_store_modifiers(data, mouse_event)
	elif input_event is InputEventJoypadButton:
		var button_event := input_event as InputEventJoypadButton
		data["type"] = "joypad_button"
		data["button_index"] = button_event.button_index
	elif input_event is InputEventJoypadMotion:
		var motion_event := input_event as InputEventJoypadMotion
		data["type"] = "joypad_motion"
		data["axis"] = motion_event.axis
		data["axis_value"] = motion_event.axis_value
	else:
		return {}

	return data


func _deserialize_input_event(value: Variant) -> InputEvent:
	if not value is Dictionary:
		return null

	var data: Dictionary = value
	var input_event: InputEvent = null

	match str(data.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			@warning_ignore("int_as_enum_without_cast")
			key_event.keycode = int(data.get("keycode", 0))
			@warning_ignore("int_as_enum_without_cast")
			key_event.physical_keycode = int(
				data.get("physical_keycode", 0)
			)
			@warning_ignore("int_as_enum_without_cast")
			key_event.key_label = int(data.get("key_label", 0))
			key_event.unicode = int(data.get("unicode", 0))
			_load_modifiers(key_event, data)
			input_event = key_event
		"mouse_button":
			var mouse_event := InputEventMouseButton.new()
			@warning_ignore("int_as_enum_without_cast")
			mouse_event.button_index = int(
				data.get("button_index", MOUSE_BUTTON_NONE)
			)
			_load_modifiers(mouse_event, data)
			input_event = mouse_event
		"joypad_button":
			var button_event := InputEventJoypadButton.new()
			@warning_ignore("int_as_enum_without_cast")
			button_event.button_index = int(data.get("button_index", 0))
			input_event = button_event
		"joypad_motion":
			var motion_event := InputEventJoypadMotion.new()
			@warning_ignore("int_as_enum_without_cast")
			motion_event.axis = int(data.get("axis", 0))
			motion_event.axis_value = float(data.get("axis_value", 0.0))
			input_event = motion_event
		_:
			return null

	input_event.device = int(data.get("device", -1))
	return input_event


func _store_modifiers(
	data: Dictionary,
	input_event: InputEventWithModifiers
) -> void:
	data["alt_pressed"] = input_event.alt_pressed
	data["shift_pressed"] = input_event.shift_pressed
	data["ctrl_pressed"] = input_event.ctrl_pressed
	data["meta_pressed"] = input_event.meta_pressed


func _load_modifiers(
	input_event: InputEventWithModifiers,
	data: Dictionary
) -> void:
	input_event.alt_pressed = bool(data.get("alt_pressed", false))
	input_event.shift_pressed = bool(data.get("shift_pressed", false))
	input_event.ctrl_pressed = bool(data.get("ctrl_pressed", false))
	input_event.meta_pressed = bool(data.get("meta_pressed", false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
