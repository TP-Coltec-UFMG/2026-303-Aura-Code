class_name SonsAsimov
extends Node
## Efeitos curtos sintetizados localmente, sem arquivos ou plugins externos.
var sons: Dictionary = {}

func _ready() -> void:
	sons["passo"] = criar([220.0, 330.0], 0.055)
	sons["erro"] = criar([180.0, 120.0], 0.10)
	sons["ok"] = criar([440.0, 554.0, 660.0], 0.085)
	sons["toque"] = criar([320.0], 0.05)

func criar(notas: Array, duracao: float) -> AudioStreamWAV:
	var dados := PackedByteArray()
	for nota in notas:
		var quantidade := int(22050 * duracao)
		for n in range(quantidade):
			var volume := minf(float(n) / 80.0, 1.0) * (1.0 - float(n) / quantidade)
			var onda := sin(TAU * float(nota) * n / 22050.0)
			var valor := int(onda * volume * 5000)
			dados.append(valor & 255)
			dados.append((valor >> 8) & 255)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	audio.data = dados
	return audio

func tocar(nome: String) -> void:
	if not Progresso.som_ativo or not sons.has(nome):
		return
	var player := AudioStreamPlayer.new()
	player.stream = sons[nome]
	player.volume_db = -10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
